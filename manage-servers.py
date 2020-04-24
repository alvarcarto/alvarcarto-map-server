from nap.url import Url
import requests
import string
import json
import random
from functools import partial
import sys
import socket
import time
import os
from os import getenv, path
from fabric import Connection, Config

import logging
import paramiko
import boto3

config = {
  'HETZNER_USER': getenv('HETZNER_USER'),
  'HETZNER_PASSWORD': getenv('HETZNER_PASSWORD'),
  'ROOT_USER_PASSWORD': getenv('ROOT_USER_PASSWORD'),
  'MAP_USER_PASSWORD': getenv('MAP_USER_PASSWORD'),
  'MAP_SERVER_INSTALL_DIR': getenv('MAP_SERVER_INSTALL_DIR', default='/home/alvar'),
  'MAP_SERVER_DATA_DIR': getenv('MAP_SERVER_DATA_DIR', default='/home/alvar/data'),
  'ALVAR_ENV': getenv('ALVAR_ENV', default='qa'),
  'AWS_ACCESS_KEY_ID': getenv('AWS_ACCESS_KEY_ID'),
  'AWS_SECRET_ACCESS_KEY': getenv('AWS_SECRET_ACCESS_KEY'),
  'GITHUB_INTEGRATION_USER_TOKEN': getenv('GITHUB_INTEGRATION_USER_TOKEN'),
  'CLOUDFLARE_TOKEN': getenv('CLOUDFLARE_TOKEN'),
  'CIRCLECI_TOKEN': getenv('CIRCLECI_TOKEN'),
}

for key, val in config.items():
  if val is None:
    raise Exception('{} env var not set!'.format(key))

INSTALL_EXIT_CODE_FILE = path.join(config['MAP_SERVER_INSTALL_DIR'], 'install_exit_code')
INSTALL_STARTED_FILE = path.join(config['MAP_SERVER_INSTALL_DIR'], 'install_started')
SECRETS_FILE_NAME = '{}.secrets.json'.format(config['ALVAR_ENV'])
SECRETS_FILE = path.join(config['MAP_SERVER_INSTALL_DIR'], SECRETS_FILE_NAME)

s3 = boto3.client('s3',
  aws_access_key_id=config['AWS_ACCESS_KEY_ID'],
  aws_secret_access_key=config['AWS_SECRET_ACCESS_KEY'],
)

logger = logging.getLogger(__file__)
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setFormatter(logging.Formatter('%(asctime)-15s %(name)-5s %(levelname)-8s: %(message)s'))
logger.addHandler(ch)

# Set to DEBUG if issues with SSH connection occur
logging.getLogger("paramiko").setLevel(logging.WARNING)


global_rollback_actions = []


class RobotApi(Url):
  def after_request(self, response):
    if response.status_code < 200 or response.status_code > 200:
      response.raise_for_status()

    return response.json()

robotApi = RobotApi('https://robot-ws.your-server.de', auth=(config['HETZNER_USER'], config['HETZNER_PASSWORD']))


class CloudflareApi(Url):
  def after_request(self, response):
    if response.status_code < 200 or response.status_code > 200:
      logger.error(response.json())
      response.raise_for_status()

    return response.json()

  def before_request(self, method, relative_url, request_kwargs):
    headers = {}
    if 'headers' in request_kwargs:
      headers = request_kwargs['headers']

    headers['Authorization'] = 'Bearer {}'.format(config['CLOUDFLARE_TOKEN'])
    headers['Content-Type'] = 'application/json'
    return extend(request_kwargs, { 'headers': headers })

cloudflareApi = CloudflareApi('https://api.cloudflare.com')


def connection(server, **kwargs):
  connect_kwargs = { 'look_for_keys': False }
  if 'ssh_key_filename' in server:
    connect_kwargs['passphrase'] = server['user_ssh_passphrase']
    connect_kwargs['key_filename'] = server['ssh_key_filename']
  elif 'password' in server:
    connect_kwargs['password'] = server['password']
  else:
    raise Exception('No password or ssh key provided!')

  new_kwargs = extend({ 'connect_timeout': 5 }, kwargs)
  config = Config(overrides={ 'sudo': { 'password': server['password'] } })
  return Connection(server['ip'], user=server['user'], config=config, connect_kwargs=connect_kwargs, **new_kwargs)


def is_server_alive(server):
  try:
    with connection(server, connect_timeout=30) as c:
      c.run('uname -s', hide=True)
    return True
  except socket.timeout:
    return False
  except TimeoutError:
    return False
  except paramiko.ssh_exception.NoValidConnectionsError:
    return False

  return False


def extend(a, b):
  return dict(a, **b)


def initiate_linux_install(ip):
  res = robotApi.post('/boot/{}/linux'.format(ip), data={
    'dist': 'Ubuntu 18.04.4 LTS minimal',
    'arch': '64',
    'lang': 'en'
  })

  logger.info('Initiated linux install for {}'.format(ip))
  return res


def force_initiate_linux_install(ip):
  try:
    return initiate_linux_install(ip)
  except requests.exceptions.HTTPError as e:
    # 409 means we have already initiated a linux reboot
    if e.response.status_code != 409:
      raise

  logger.info('Linux installation already initiated for {}, redoing it ..'.format(ip))
  robotApi.delete('/boot/{}/linux'.format(ip))
  return initiate_linux_install(ip)


def hardware_reboot(ip):
  robotApi.post('/reset/{}'.format(ip), data={ 'type': 'hw' })
  logger.info('Reboot request sent for {} '.format(ip))
  time.sleep(10)


def reboot(server):
  logger.info('Rebooting server ..')
  with connection(server) as c:
    c.run('reboot')
  time.sleep(10)


def format_and_reinstall_ubuntu(ip):
  details = force_initiate_linux_install(ip)
  logger.info('Got following details for reinstall: {}'.format(details))

  # These waits are done for just in case. Previously the reinstall wasn't registered
  # before we started doing other operations and we ran some setup tasks before the reinstall
  # was actually executed
  # I couldn't find a way to wait for the installation to finish via their API:
  # https://robot.your-server.de/doc/webservice/en.html#post-boot-server-ip-linux
  logger.info('Waiting 30s for linux install to register ..')
  time.sleep(30)
  hardware_reboot(ip)
  logger.info('Waiting 5 minutes for linux installation to finish ..')
  time.sleep(60 * 5)
  # Another log message is needed so circle ci doesn't kill the job
  logger.info('Waiting 5 more minutes for linux installation to finish ..')
  time.sleep(60 * 5)

  return details


def from_s3_to_server(server, s3_file_name, server_path):
  logger.info('Downloading {} from S3 to remote path {} ..'.format(s3_file_name, server_path))
  s3.download_file('alvarcarto-keys', s3_file_name, s3_file_name)
  with connection(server) as c:
    c.put(s3_file_name, server_path)
  os.remove(s3_file_name)


def wait_until_responsive(server, wait_time=3, total_max_wait_time=60 * 10):
  start_time = time.time()
  while not is_server_alive(server):
    total_wait_time = time.time() - start_time
    if total_wait_time > total_max_wait_time:
      raise Exception('Timout while waiting server to become responsive!')

    logger.info('Waiting until server {ip} is responsive ..'.format(**server))
    time.sleep(wait_time)

  logger.info('Server {ip} is alive'.format(**server))


def generate_random_password(n):
  return ''.join(random.SystemRandom().choice(string.ascii_letters + string.digits) for _ in range(n))


def update_dns_record(zone_id, record_id, data):
  cloudflareApi.put('/client/v4/zones/{}/dns_records/{}'.format(zone_id, record_id), data=json.dumps(data))


def get_dns_records():
  # Note: 400 error might be returned when invalid token provided
  res = cloudflareApi.get('/client/v4/zones', params={ 'name': 'alvarcarto.com' })
  zone_id = res['result'][0]['id']

  records = {}
  names = ['tile-api', 'tile-api-reserve', 'cached-tile-api', 'cached-tile-api-reserve']
  for name in names:
    res = cloudflareApi.get('/client/v4/zones/{}/dns_records'.format(zone_id), params={ 'name': '{}.alvarcarto.com'.format(name) })
    records[name] = {
      'ip': res['result'][0]['content'],
      'result': res['result'][0],
    }

    record_type = res['result'][0]['type']
    if record_type != 'A':
      raise Exception('Unexcepted DNS record type found: {}'.format(record_type))

  logger.info('DNS records:')
  logger.info(json.dumps(records))
  logger.info('')
  for name, record in records.items():
    logger.info('{}.alvarcarto.com = {}'.format(name, records[name]['ip']))
  logger.info('\n')

  return records


def initialise_as_root(server):
  logger.info('Running root tasks for {ip} ..'.format(**server))

  with connection(server) as c:
    logger.info('Changing root password ..')
    new_root_pass = config['ROOT_USER_PASSWORD']
    c.run('echo -e "{user}:{password}" | chpasswd'.format(user='root', password=new_root_pass))

    logger.info('Installing packages ..')
    c.run('apt-get autoclean && apt-get autoremove && apt-get update')
    c.run('apt-get -y upgrade')
    c.run('apt-get -y install locales && locale-gen en_US.UTF-8')
    c.run('apt-get install -y sudo openssl git nano screen postgresql-client')

    logger.info('Adding map user ..')
    c.run('useradd --shell /bin/bash --create-home --home /home/alvar alvar')
    c.run('adduser alvar sudo')

    new_alvar_pass = config['MAP_USER_PASSWORD']
    c.run('echo -e "{user}:{password}" | chpasswd'.format(user='alvar', password=new_alvar_pass))

    # Always use visudo for editing, but in this case we need a non-interactive command
    # Disable password for alvar user for the installation duration
    c.run('echo -e "\nalvar ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers')


def start_install_as_map_user(server):
  logger.info('Start installation as map user at {ip} ..'.format(**server))

  with connection(server) as c:
    logger.info('Adding SSH key ..')
    # Add SSH key
    c.run('mkdir -p ~/.ssh')
    c.run('chmod 700 .ssh')
    pub_key_file = 'alvarcarto-server-key.pub'
    remote_pub_key_file = path.join(config['MAP_SERVER_INSTALL_DIR'], pub_key_file)
    from_s3_to_server(server, pub_key_file, remote_pub_key_file)
    c.run('cat {} >> ~/.ssh/authorized_keys'.format(remote_pub_key_file))
    c.run('rm {}'.format(remote_pub_key_file))

    logger.info('Starting installation inside screen ..')
    # Increase scrollback to 1M lines
    c.run('echo "defscrollback 1000000" >> ~/.screenrc')
    c.run('echo "deflog on" >> ~/.screenrc')
    c.run('echo "logfile /home/alvar/screenlog.%n" >> ~/.screenrc')

    from_s3_to_server(server, SECRETS_FILE_NAME, SECRETS_FILE)
    c.run('sudo apt-get install -y jq')
    temp_file = '{}.tmp'.format(SECRETS_FILE)
    c.run('jq \'. + {{ map_server_install_dir: "{}", map_server_data_dir: "{}"}}\' {} > {}'.format(
      config['MAP_SERVER_INSTALL_DIR'],
      config['MAP_SERVER_DATA_DIR'],
      SECRETS_FILE,
      temp_file
    ))
    c.run('mv {} {}'.format(temp_file, SECRETS_FILE))

    clone_url = 'https://alvarcarto-integration:{password}@github.com/alvarcarto/alvarcarto-map-server.git'.format(password=config['GITHUB_INTEGRATION_USER_TOKEN'])
    repo_dir = path.join(config['MAP_SERVER_INSTALL_DIR'], 'alvarcarto-map-server')
    c.run('git clone {} {}'.format(clone_url, repo_dir))
    with c.cd(repo_dir):
      # These commands are all executed regardless of the exit codes of individual steps
      # That is needed, we want to always launch the wait task in circle ci to show the status
      # even if the install failed
      cmd = '; '.join([
        'ALVAR_MAP_SERVER_INSTALL_DIR={} ALVAR_MAP_SERVER_DATA_DIR={} ALVAR_ENV={} bash install.sh'.format(config['MAP_SERVER_INSTALL_DIR'], config['MAP_SERVER_DATA_DIR'], config['ALVAR_ENV']),
        'echo "$?" > {}'.format(INSTALL_EXIT_CODE_FILE),
        'CIRCLECI_TOKEN="{}" bash .circleci/launch-wait.sh'.format(config['CIRCLECI_TOKEN'])
      ])
      # Screen command will immediately detach and run in background
      c.run('screen -S install -dm bash -c \'{}\''.format(cmd))

      c.run('touch {}'.format(INSTALL_STARTED_FILE))
      logger.info('Installation started as map user at {ip} ..'.format(**server))


def is_install_ready_to_continue(server):
  with connection(server) as c:
    logger.info('Testing if {} exists ..'.format(INSTALL_STARTED_FILE))
    start_file_exists = c.run('test -f {}'.format(INSTALL_STARTED_FILE), hide=True, warn=True).exited == 0
    if not start_file_exists:
      raise Exception('Install has not been started, {} doesn\'t exist'.format(start_file))

    exit_file_exists = c.run('test -f {}'.format(INSTALL_EXIT_CODE_FILE), hide=True, warn=True).exited == 0
    if not exit_file_exists:
      return False

    result = c.run('cat {}'.format(INSTALL_EXIT_CODE_FILE), hide=True).stdout.strip()
    if result != '0':
      raise Exception('install.sh exited with non-zero exit code!')

    return True


def run_after_installation_tasks(server):
  logger.info('Run tasks after map server installation at {ip} ..'.format(**server))

  with connection(server) as c:
    logger.info('Installing cloudflare certificates and keys ..')
    cert_file = 'cloudflare-origin-cert.pem'
    remote_cert_file = path.join(config['MAP_SERVER_INSTALL_DIR'], cert_file)
    from_s3_to_server(server, cert_file, remote_cert_file)

    key_file = 'cloudflare-origin-key.pem'
    remote_key_file = path.join(config['MAP_SERVER_INSTALL_DIR'], key_file)
    from_s3_to_server(server, key_file, remote_key_file)

    c.run('sudo mkdir -p /etc/caddy', warn=True)
    c.run('sudo mv {} /etc/caddy/cert.pem'.format(remote_cert_file))
    c.run('sudo mv {} /etc/caddy/key.pem'.format(remote_key_file))
    c.run('sudo chown caddy:caddy /etc/caddy/cert.pem /etc/caddy/key.pem')
    c.run('sudo chmod 644 /etc/caddy/cert.pem')
    c.run('sudo chmod 600 /etc/caddy/key.pem')

    logger.info('SSH configuration ..')
    c.run('sudo sed -i \'s/PermitRootLogin yes/PermitRootLogin no/g\' /etc/ssh/sshd_config')
    # Note: in OSX, you need -i "" instead of just -i for this to work
    c.run('sudo sed -E -i \'s/^(Subsystem.*sftp.*)$/#\\1/g\' /etc/ssh/sshd_config')
    c.run('sudo bash -c \'echo -e "\n# Force safer protocol\nProtocol 2" >> /etc/ssh/sshd_config\'')
    c.run('sudo bash -c \'echo -e "\nPermitEmptyPasswords no" >> /etc/ssh/sshd_config\'')
    c.run('sudo sed -i \'s/X11Forwarding yes/X11Forwarding no/g\' /etc/ssh/sshd_config')
    c.run('sudo service ssh restart')

    logger.info('Remove temporary files ..')
    c.run('rm {}'.format(INSTALL_STARTED_FILE))
    c.run('rm {}'.format(INSTALL_EXIT_CODE_FILE))
    c.run('rm {}'.format(SECRETS_FILE))

    logger.info('Run final system upgrades before reboot ..')
    c.run('sudo apt-get -y upgrade')

    logger.info('Disable unsecure sudo settings added for installation ..')
    c.run('sudo sed -E -i \'s/^(alvar ALL=\\(ALL\\) NOPASSWD: ALL.*)$/#\\1/g\' /etc/sudoers')


def task_start_install():
  records = get_dns_records()
  server = {
    'ip': records['tile-api-reserve']['ip'],
  }

  details = format_and_reinstall_ubuntu(server['ip'])
  asRoot = extend(server, { 'user': 'root', 'password': details['linux']['password'] })
  # Waiting for maximum of 30 additional minutes for installation to finish
  # Sometimes the linux installation takes a long time or does not finish
  # It is possible that it happens only in development mode when the server reinstall is
  # done multiple times in a short time
  wait_until_responsive(asRoot, wait_time=30, total_max_wait_time=60 * 30)

  # TODO: if reinstall issues persists, we can order a manual reboot after
  #       waiting 30 minutes. Manual reset may take even 2 hours, so it should be
  #       properly waited
  #       See https://github.com/aszlig/hetzner/blob/master/hetzner/reset.py#L116
  initialise_as_root(asRoot)

  asMapUser = extend(server, { 'user': 'alvar', 'password': config['MAP_USER_PASSWORD'] })
  start_install_as_map_user(asMapUser)
  wait_until_responsive(asMapUser, wait_time=30)


def task_is_install_ready_to_continue():
  records = get_dns_records()

  asMapUser = {
    'ip': records['tile-api-reserve']['ip'],
    'user': 'alvar',
    'password': config['MAP_USER_PASSWORD']
  }

  try:
    ready = is_install_ready_to_continue(asMapUser)
  except TimeoutError:
    return 'false'

  if ready:
    logger.info('Install is ready to continue!')
    return 'true'

  logger.info('Install is not ready yet')
  return 'false'


def task_get_tile_api_reserve_ip():
  records = get_dns_records()
  return records['tile-api-reserve']['ip']


def task_get_tile_api_ip():
  records = get_dns_records()
  return records['tile-api']['ip']


def task_finish_install():
  records = get_dns_records()
  asMapUser = {
    'ip': records['tile-api-reserve']['ip'],
    'user': 'alvar',
    'password': config['MAP_USER_PASSWORD']
  }

  run_after_installation_tasks(asMapUser)
  hardware_reboot(asMapUser['ip'])
  wait_until_responsive(asMapUser)


def task_download_file(remote_path, local_path):
  records = get_dns_records()
  asMapUser = {
    'ip': records['tile-api-reserve']['ip'],
    'user': 'alvar',
    'password': config['MAP_USER_PASSWORD']
  }

  with connection(asMapUser) as c:
    logger.info('Downloading remote file {} to local {} ..'.format(remote_path, local_path))
    c.get(remote_path, local_path)
    logger.info('Download done!')


def task_clear_cached_tile_api():
  records = get_dns_records()
  asMapUser = {
    'ip': records['cached-tile-api']['ip'],
    'user': 'alvar',
    'password': config['MAP_USER_PASSWORD']
  }

  with connection(asMapUser) as c:
    logger.info('Clearing cache folder in cached-tile-api.alvarcarto.com .. ')
    c.run('du -sh /cache/files')
    c.run('find /cache/files -maxdepth 1 -type f -delete')
    logger.info('Cache cleared!')


def task_purge_cloudflare_cache():
  records = get_dns_records()
  # Note: 400 error might be returned when invalid token provided
  res = cloudflareApi.get('/client/v4/zones', params={ 'name': 'alvarcarto.com' })
  zone_id = res['result'][0]['id']

  logger.info('Sending a request to clear EVERYTHING from cache for alvarcarto.com zone ..')
  cloudflareApi.post('/client/v4/zones/{}/purge_cache'.format(zone_id), data=json.dumps({ 'purge_everything': True }))
  logger.info('Cache purge called!')


def task_promote_reserve_to_production():
  records = get_dns_records()
  switch_pairs = [('tile-api-reserve', 'tile-api')]

  logger.info('Promoting to production!')
  logger.info('\n'.join(map(lambda p: '{} -> {}'.format(p[0], p[1]), switch_pairs)))

  for pair in switch_pairs:
    # Iterate both ways
    for name1, name2 in ((pair[0], pair[1]), (pair[1], pair[0])):
      zone_id = records[name1]['result']['zone_id']
      record_id = records[name1]['result']['id']
      data = {
        # Switch ip
        'content': records[name2]['ip'],
        'type': records[name1]['result']['type'],
        'name': records[name1]['result']['name'],
        'proxied': records[name1]['result']['proxied'],
        'ttl': records[name1]['result']['ttl'],
      }

      update_dns_record(zone_id, record_id, data)
      logger.info('Updated record {} -> {} (previously {})'.format(data['name'], data['content'], records[name1]['ip']))

      # In case we need to rollback, we update the record to have same data as before
      rollback_data = extend(data, { 'content': records[name1]['ip'] })
      rollback_action = partial(update_dns_record, zone_id, record_id, rollback_data)
      global_rollback_actions.append({
        'action': rollback_action,
        'message': 'Rollbacking record {} -> {} ..'.format(data['name'], rollback_data['content'])
      })


def wrap_with_rollback(func):
  def run_func(*args, **kwargs):
    try:
      return func(*args, **kwargs)
    except Exception as e:
      logger.error('Exception raised: {}'.format(e))
      if len(global_rollback_actions) == 0:
        raise

      logger.error('SERIOUS WARNING! Rollbacks are executed!')
      try:
        for rollback_info in global_rollback_actions:
          logger.info(rollback_info['message'])
          rollback_info['action']()
      except:
        logger.error('Original error {}'.format(e))
        logger.error('Rollback function failed!')
        raise

  return run_func


def execute_task(task, *task_args):
  tasks = {
    'start_install': wrap_with_rollback(task_start_install),
    'is_install_ready_to_continue': wrap_with_rollback(task_is_install_ready_to_continue),
    'finish_install': wrap_with_rollback(task_finish_install),
    'download_file': wrap_with_rollback(task_download_file),
    'get_tile_api_reserve_ip': wrap_with_rollback(task_get_tile_api_reserve_ip),
    'get_tile_api_ip': wrap_with_rollback(task_get_tile_api_ip),
    'clear_cached_tile_api': wrap_with_rollback(task_clear_cached_tile_api),
    'purge_cloudflare_cache': wrap_with_rollback(task_purge_cloudflare_cache),
    'promote_reserve_to_production': wrap_with_rollback(task_promote_reserve_to_production),
  }

  if not task in tasks:
    logger.error('No such task: {}'.format(task))
    sys.exit(1)

  logger.info('Running task {}'.format(task))
  task_func = tasks[task]
  result = task_func(*task_args)

  # If the task returns result output, the individual steps should not output anything else
  # to stdout!
  if result is not None:
    print(result)


def print_err(*args, **kwargs):
  print(*args, file=sys.stderr, **kwargs)


# Note: only use stdout for command output, not for logging!
if __name__ == "__main__":
  if len(sys.argv) < 2:
    print_err('Usage: python {} <task_name> [parameters]'.format(__file__))

    print_err('Example:')
    print_err('  python {} start_install\n'.format(__file__))
    print_err('  python {} download_file <remote_path> <local_path>\n'.format(__file__))
    sys.exit(2)

  head, *tail = sys.argv
  task, *task_args = tail
  execute_task(task, *task_args)
