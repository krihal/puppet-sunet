define sunet::luna_client($hostname = undef) {
   $client_hostname = $hostname ? {
      undef    => "${::fqdn}",
      default  => $hostname
   }
   $pin = hiera("luna_partition_password")
   sunet::docker_run { "${name}_luna_client":
      image    => 'docker.sunet.se/luna-client',
      imagetag => 'latest',
      env      => ["PKCS11PIN=${pin}"],
      volumes  => ["/dev/log:/dev/log","/etc/luna/cert:/usr/safenet/lunaclient/cert"],
      hostname => $client_hostname
   }
}