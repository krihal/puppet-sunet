define sunet::ucrandom(
   $port="4711",
   $device="/dev/random") {

   file {'/usr/bin/ucrandom':
      owner   => root,
      group   => root,
      mode    => '0755',
      content => template("sunet/ucrandom/ucrandom.erb")
   } ->
   file {'/etc/default': ensure => directory } ->
   file {'/etc/default/ucrandom':
      ensure  => file,
      owner   => root,
      group   => root,
      mode    => '0660',
      content => template("sunet/ucrandom/default.erb")
   }
   case $::init_type {
      'upstart': {
         file {'/etc/init/ucrandom.conf':
           ensure  => file,
           owner   => root,
           group   => root,
           mode    => '0660',
           content => template("sunet/ucrandom/ucrandom.conf.erb")
         }
      }
      'systemd-sysv': {
         file {'/lib/systemd/system/ucrandom.service':
           ensure  => file,
           owner   => root,
           group   => root,
           mode    => '0600',
           content => template("sunet/ucrandom/ucrandom.unit.erb")
         }
      }
   }
   $_provider = $::init_type ? {
      'upstart'      => 'upstart',
      'systemd-sysv' => 'systemd',
      default        => 'debian'
   }
   service {'ucrandom': ensure => running, provider => $_provider }
}
