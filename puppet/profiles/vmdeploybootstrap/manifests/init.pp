class vmdeploybootstrap($interface,$ip,$netmask,$gateway,$hostname,$domainname,$dnsservers,$searchdomains) {
  $a_dnsservers    = inline_template("<%= @dnsservers.join ' ' %>")
  $a_searchdomains = inline_template("<%= @searchdomains.join ' ' %>")
  $network         = inline_template("<%= require 'ipaddr'; IPAddr.new(scope.lookupvar('ip')).mask(scope.lookupvar('netmask')).to_s %>")
  $broadcast       = inline_template("<%= require 'ipaddr'; IPAddr.new(scope.lookupvar('ip')).mask(scope.lookupvar('netmask')).to_range.last.to_s %>")

  package { 'augeas-tools': ensure  => 'latest' }

  augeas { 'vmdeploy_interface':
    require => Package['augeas-tools'],
    context => "/files/etc/network/interfaces/iface[. = '$interface']",
    changes => [
      "set method static",
      "set address $ip",
      "set netmask $netmask",
      "set network $network",
      "set broadcast $broadcast",
      "set gateway $gateway",
      "set dns-nameservers '$a_dnsservers'",
      "set dns-search '$a_searchdomains'"
    ]
  }

  file { '/etc/hostname':
    require => Augeas['vmdeploy_interface'],
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => 644,
    content => "$hostname\n"
  }

  # adds after 127.0.0.1, which is assumed to exist
  augeas { 'vmdeploy_etc_hosts_add':
    require => Package['augeas-tools'],
    context => "/files/etc/hosts",
    changes => [
      "ins 01 after *[ipaddr='127.0.0.1']",
      "set 01/ipaddr '$ip'",
      "set 01/canonical '$hostname.$domainname'",
      "set 01/alias[1] '$hostname'"
    ],
    onlyif => "match *[ipaddr='$ip'] size == 0"
  }

  augeas { 'vmdeploy_etc_hosts_edit':
    require => Package['augeas-tools'],
    context => "/files/etc/hosts",
    changes => [
      "set *[ipaddr='$ip']/canonical '$hostname.$domainname'",
      "set *[ipaddr='$ip']/alias[1] '$hostname'"
    ],
    onlyif => "match *[ipaddr='$ip'] size != 0"
  }
}
