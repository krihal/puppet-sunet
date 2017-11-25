class sunet::ni3(

  $test_server = false,
  $backup_server = false,
  String $ssl_cert,
  String $ssl_key,

){ 
  
  $neo4j_pwd = safe_hiera('ni_neo4j_password',[])
  $ni_database_pwd = safe_hiera ('ni_database_password',[])
  $noclook_secret_key = safe_hiera ('noclook_secret_key',[])
  $google_api_key = safe_hiera ('google_api_key',[])
  $domain = $::domain
  $hostname = $::hostname 

  service { 'neo4j':
    ensure => running,
    enable => true,
  }

  service { 'uwsgi':
    ensure => running,
    enable => true,
  }

  service { 'nginx':
    ensure => running,
    enable => true,
  }

  file { '/etc/neo4j/neo4j.conf':
    ensure => file,
    mode => '644',
    content => template('sunet/ni3/neo4j.conf.erb'), 
    notify => Service['neo4j'],
  }

  file {'/var/lib/neo4j/data/dbms/auth':
    ensure => absent,
  }

  exec {'change_neo4j_pwd':
    command => "neo4j-admin set-initial-password $neo4j_pwd",
  }
  
  file {'/root/entries.sql':
    ensure => file,
    mode => '644',
    content => template('sunet/ni3/entries.sql.erb'),
  }
  
  exec {'postgres_entries':
    user => 'postgres',
    command => "psql -f /root/entries.sql",
    subscribe => File['/root/entries.sql'],
    refreshonly => true,
  }
  
  user {'ni':
    ensure => present,
    password => '*',
    home => '/var/opt/norduni',
  } ->

  file { '/var/opt/norduni':
    ensure  => directory,
    owner   => 'ni',
    group   => 'ni',
  }

  vcsrepo {'/var/opt/norduni/norduni':
    ensure => present,
    provider => git,
    owner => ni,
    group => ni,
    source => 'git://git.nordu.net/norduni.git',
    require => User['ni'],
  }

  python::virtualenv {'/var/opt/norduni/norduni_environment':
    ensure => present,
    requirements => '/var/opt/norduni/norduni/requirements/prod.txt',
    owner => 'ni',
    group =>'ni',
    cwd => '/var/opt/norduni/norduni_environment',
    require => Vcsrepo['/var/opt/norduni/norduni'],
  } ->
  
  file { '/var/opt/norduni/norduni/src/niweb/.env':
    ensure => present,
    mode  => '664',
    owner => 'ni',
    group => 'ni',
    content  => template('sunet/ni3/.env.erb'),
    notify => Service['uwsgi'], 
  } ->

  file {'/root/python_commands':
    ensure => file,
    mode => '755',
    content => template('sunet/ni3/python_commands.erb'),
  } ->

  exec {'python_commands':
    command => "/root/python_commands",
    subscribe => File['/root/python_commands'],
    refreshonly => true,
  } ->

  if $domain == 'sunet.se'{ 
     vcsrepo {'/var/opt/norduni/sunet-nistore':
     ensure => latest,
     provider => git,
     owner => ni,
     group => ni,
     source => 'git://git.nordu.net/sunet-nistore.git',
     require => User['ni'],
     } 
  } 

  if $domain == 'nordu.net'{
     vcsrepo {'/var/opt/norduni/nistore':
     ensure => latest,
     provider => git,
     owner => ni,
     group => ni,
     source => 'git://git.nordu.net/nistore.git',
     require => User['ni'],
     } 
  } 

  file {'/var/opt/norduni/norduni/src/scripts/restore.conf/':
    ensure => file,
    mode  => '644',
    owner => 'ni',
    group => 'ni',
    content  => template('sunet/ni3/restore.conf.erb'),   
  } 

  if $test_server{
     file {'/var/opt/norduni/consume.sh/':
       ensure => file,
       mode => '755',
       content => template('sunet/ni3/consume.sh.erb'),
     }

     file {'/var/opt/norduni/norduni/src/scripts/sunet.conf':
       ensure => file,
       mode => '644',
       owner => 'ni',
       group => 'ni',
       content => template('sunet/ni3/sunet.conf.erb'),
     }

     sunet::scriptherder::cronjob { 'run_clone_script':
       cmd => "/var/opt/norduni/norduni/src/scripts/clone.sh -r /var/opt/norduni/sunet-nistore/",
       user => 'ni',
       minute => '30',
       hour => '6',
       monthday => '1',
       ok_criteria   => ['exit_status=0', 'max_age=721h'],
       warn_criteria => ['exit_status=0', 'max_age=723h'],
    }
    
    sunet::scriptherder::cronjob { 'run_consume_script':
       cmd => "/var/opt/norduni/consume.sh",
       user => 'ni',
       minute => '30',
       hour => '6',
       ok_criteria   => ['exit_status=0', 'max_age=25h'],
       warn_criteria => ['exit_status=0', 'max_age=49h'],
    }
  }

  if $backup_server{

     exec { 'create_dhparam_pem':
       command => 'openssl dhparam -out /etc/ssl/dhparams.pem 2048',
       unless  => '/usr/bin/test -s /etc/ssl/dhparams.pem',
     }

     sunet::scriptherder::cronjob {'run_clone_script_ni2':
       command => "/var/opt/norduni/norduni/src/scripts/clone.sh -r /var/opt/norduni/sunet-nistore/",
       user => 'ni',
       minute => '30',
       hour => '6',
       ok_criteria   => ['exit_status=0', 'max_age=25h'],
       warn_criteria => ['exit_status=0', 'max_age=49h'],
     }
  }

  file { '/etc/uwsgi/apps-available/noclook.ini':
    ensure => present,
    mode  => '644',
    content  => template('sunet/ni3/noclook.ini.erb'),
    notify => Service['uwsgi'],
  } ->

  file { '/etc/uwsgi/apps-enabled/noclook.ini':
    ensure => link,
    target => '/etc/uwsgi/apps-available/noclook.ini',
  }   
  
  file { '/tmp/django_cache':
    ensure => directory,
    owner => 'ni',
    group => 'www-data',
    mode => '775',
    recurse => true,
  }

  file { '/var/opt/norduni/norduni/src/niweb/logs/':
    ensure => directory,
    owner => 'ni',
    group => 'www-data',
    mode => '775',
    recurse => true,
  }

  file { '/etc/nginx/sites-available/default':
    ensure => file,
    mode => '644',
    content => template('sunet/ni3/default.erb'),
    notify => Service['nginx'],
  } 
 }