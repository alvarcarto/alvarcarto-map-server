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
}

for key, val in config.items():
  if val is None:
    raise Exception('{} env var not set!'.format(key))

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

  config = Config(overrides={ 'sudo': { 'password': server['password'] } })
  return Connection(server['ip'], user=server['user'], config=config, connect_kwargs=connect_kwargs, **kwargs)


def is_server_alive(server):
  try:
    with connection(server, connect_timeout=3) as c:
      c.run('uname -s', hide=True)
    return True
  except socket.timeout:
    return False

  return False


def extend(a, b):
  return dict(a, **b)


def initiate_linux_install(server):
  res = robotApi.post('/boot/{ip}/linux'.format(**server), data={
    'dist': 'Ubuntu 18.04.4 LTS minimal',
    'arch': '64',
    'lang': 'en'
  })

  logger.info('Initiated linux install for {ip}'.format(**server))
  return res


def force_initiate_linux_install(server):
  try:
    return initiate_linux_install(server)
  except requests.exceptions.HTTPError as e:
    # 409 means we have already initiated a linux reboot
    if e.response.status_code != 409:
      raise

  logger.info('Linux installation already initiated for {ip}, redoing it ..'.format(**server))
  robotApi.delete('/boot/{ip}/linux'.format(**server))
  return initiate_linux_install(server)


def hardware_reboot(server):
  robotApi.post('/reset/{ip}'.format(**server), data={ 'type': 'hw' })
  logger.info('Hardware reset request sent for {ip} '.format(**server))


def format_and_reinstall_ubuntu(server):
  details = force_initiate_linux_install(server)
  hardware_reboot(server)

  return details


def wait_until_responsive(server, wait_time=3, total_max_wait_time=60 * 10):
  start_time = time.time()
  while not is_server_alive(server):
    total_wait_time = time.time() - start_time
    if total_wait_time > total_max_wait_time:
      raise Exception('Timout while waiting server to become responsive!')

    logger.info('Waiting server {ip} is responsive ..'.format(**server))
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

  return records


def initialise_as_root(server):
  logger.info('Running root tasks for {ip} ..'.format(**server))

  with connection(server) as c:
    new_root_pass = config['ROOT_USER_PASSWORD']
    c.run('echo -e "{user}:{password}" | chpasswd'.format(user='root', password=new_root_pass))

    c.run('apt-get autoclean && apt-get autoremove && apt-get update')
    c.run('apt-get -y install locales && locale-gen en_US.UTF-8')
    c.run('apt-get install -y sudo openssl git nano screen postgresql-client')
    c.run('useradd --shell /bin/bash --create-home --home /home/alvar alvar')
    c.run('adduser alvar sudo')

    new_alvar_pass = config['MAP_USER_PASSWORD']
    c.run('echo -e "{user}:{password}" | chpasswd'.format(user='alvar', password=new_alvar_pass))

    # Always use visudo for editing, but in this case we need a non-interactive command
    # Disable password for alvar user for the installation duration
    c.run('echo -e "\nalvar ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers')


def start_install_as_map_user(server):
  logger.info('Start installation as alvar at {ip} ..'.format(**server))

  with connection(server) as c:
    # Increase scrollback to 1M lines
    c.run('echo "defscrollback 1000000" >> ~/.screenrc')
    c.run('echo "deflog on" >> ~/.screenrc')
    c.run('echo "logfile /home/alvar/screenlog.%n" >> ~/.screenrc')

    clone_url = 'https://alvarcarto-integration:{password}@github.com/alvarcarto/alvarcarto-map-server.git'.format(password=config['GITHUB_INTEGRATION_USER_TOKEN'])
    repo_dir = path.join(config['MAP_SERVER_INSTALL_DIR'], 'alvarcarto-map-server')
    c.run('git clone {clone_url} {repo_dir}'.format(clone_url=clone_url, repo_dir=repo_dir))
    with c.cd(repo_dir):
      c.run('touch {}'.format(path.join(config['MAP_SERVER_INSTALL_DIR'], 'install_started')))
      c.run('screen -S install -dm ALVAR_MAP_SERVER_DATA_DIR={} ALVAR_ENV={} bash install.sh'.format(config['MAP_SERVER_DATA_DIR'], config['ALVAR_ENV']))


def is_install_ready(server):
  with connection(server) as c:
    start_file = path.join(config['MAP_SERVER_INSTALL_DIR'], 'install_started')
    if c.run('test -f {}'.format(start_file), warn=True).failed:
      raise Exception('Install has not been started, {} doesn\'t exist'.format(start_file))

    result = c.run('screen -list | grep -q "install"')
    return result.exited == 0


def run_after_installation_tasks(server):
  logger.info('Run tasks after map server installation at {ip} ..'.format(**server))

  with connection(server) as c:
    # Install cloudflare origin certificate and keys
    cert_file = 'cloudflare-origin-cert.pem'
    key_file = 'cloudflare-origin-key.pem'
    remote_cert_file = path.join(config['MAP_SERVER_INSTALL_DIR'], cert_file)
    remote_key_file = path.join(config['MAP_SERVER_INSTALL_DIR'], key_file)
    s3.download_file('alvarcarto-keys', cert_file, cert_file)
    s3.download_file('alvarcarto-keys', key_file, key_file)
    c.put(cert_file, remote_cert_file)
    c.put(key_file, remote_key_file)
    os.remove(cert_file)
    os.remove(key_file)

    c.run('sudo mkdir -p /etc/caddy')
    c.run('sudo mv {remote_cert_file} /etc/caddy/cert.pem'.format(remote_cert_file=remote_cert_file))
    c.run('sudo mv {remote_key_file} /etc/caddy/key.pem'.format(remote_key_file=remote_key_file))
    c.run('sudo chown www-data:www-data /etc/caddy/cert.pem /etc/caddy/key.pem')
    c.run('sudo chmod 644 /etc/caddy/cert.pem')
    c.run('sudo chmod 600 /etc/caddy/key.pem')

    # SSH configuration
    c.run('sudo sed -i \'s/PermitRootLogin yes/PermitRootLogin no/g\' /etc/ssh/sshd_config')
    # Note: in OSX, you need -i "" instead of just -i for this to work
    c.run('sudo sed -E -i \'s/^(Subsystem.*sftp.*)$/#\\1/g\' /etc/ssh/sshd_config')
    c.run('sudo echo -e "\n# Force safer protocol\nProtocol 2" >> /etc/ssh/sshd_config')
    c.run('sudo echo -e "\nPermitEmptyPasswords no" >> /etc/ssh/sshd_config')
    c.run('sudo sed -i \'s/X11Forwarding yes/X11Forwarding no/g\' /etc/ssh/sshd_config')
    c.run('sudo service ssh restart')

    # Add SSH key
    pub_key_file = 'alvarcarto-server-key.pub'
    remote_pub_key_file = path.join(config['MAP_SERVER_INSTALL_DIR'], pub_key_file)
    s3.download_file('alvarcarto-keys', pub_key_file, pub_key_file)
    c.put(pub_key_file, remote_pub_key_file)
    os.remove(pub_key_file)
    c.run('cat {remote_pub_key_file} >> ~/.ssh/authorized_keys'.format(remote_pub_key_file=remote_pub_key_file))
    c.run('rm {remote_pub_key_file}'.format(remote_pub_key_file=remote_pub_key_file))

    # Disable unsecure sudo settings added for installation
    c.run('sudo sed -E -i \'s/^(alvar ALL=(ALL) NOPASSWD: ALL.*)$/#\\1/g\' /etc/sudoers')


def task_start_install(records):
  server = {
    'ip': records['tile-api-reserve']['ip'],
  }

  details = format_and_reinstall_ubuntu(server)
  logger.info('Got following details for reinstall: {}'.format(details))
  asRoot = extend(server, { 'user': 'root', 'password': details['linux']['password'] })
  wait_until_responsive(asRoot, wait_time=30)
  initialise_as_root(asRoot)

  asMapUser = extend(server, { 'user': 'alvar', 'password': config['MAP_USER_PASSWORD'] })
  start_install_as_map_user(asMapUser)


def task_is_install_ready(records):
  asMapUser = {
    'ip': records['tile-api-reserve']['ip'],
    'user': 'alvar',
    'password': config['MAP_USER_PASSWORD']
  }

  ready = is_install_ready(asMapUser)
  if ready:
    print('true')
  else:
    print('false')


def task_get_tile_api_reserve_ip(records):
  print(records['tile-api-reserve']['ip'])


def task_get_tile_api_ip(records):
  print(records['tile-api']['ip'])


def task_finish_install(records):
  asMapUser = {
    'ip': records['tile-api-reserve']['ip'],
    'user': 'alvar',
    'password': config['MAP_USER_PASSWORD']
  }

  run_after_installation_tasks(asMapUser)
  hardware_reboot(server)
  wait_until_responsive(asMapUser)


def task_clear_cached_tile_api(records):
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


def task_purge_cloudflare_cache(records):
  # Note: 400 error might be returned when invalid token provided
  res = cloudflareApi.get('/client/v4/zones', params={ 'name': 'alvarcarto.com' })
  zone_id = res['result'][0]['id']

  logger.info('Sending a request to clear EVERYTHING from cache for alvarcarto.com zone ..')
  cloudflareApi.post('/client/v4/zones/{}/purge_cache'.format(zone_id), data=json.dumps({ 'purge_everything': True }))
  logger.info('Cache purge called!')


def task_promote_reserve_to_production(records):
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
      func(*args, **kwargs)
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


def execute_task(task):
  records = get_dns_records()
  logger.info('DNS records at start:')
  logger.info(json.dumps(records))
  print('')
  for name, record in records.items():
    logger.info('{}.alvarcarto.com = {}'.format(name, records[name]['ip']))
  print('\n')

  tasks = {
    'start_install': wrap_with_rollback(task_start_install),
    'is_install_ready': wrap_with_rollback(task_is_install_ready),
    'finish_install': wrap_with_rollback(task_finish_install),
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
  task_func(records)


if __name__ == "__main__":
  if len(sys.argv) != 2:
    print('Usage: python {} <task_name>'.format(__file__))

    print('Example:')
    print('  python {} start_install\n'.format(__file__))
    sys.exit(2)

  execute_task(sys.argv[1])
