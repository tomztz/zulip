class zulip::smokescreen {
  include zulip::supervisor
  include zulip::golang

  $version = $zulip::common::versions['smokescreen-src']['version']
  $dir = "/srv/zulip-smokescreen-src-${version}"
  $bin = "/usr/local/bin/smokescreen-${version}-go-${zulip::golang::version}"

  zulip::external_dep { 'smokescreen-src':
    version        => $version,
    url            => "https://github.com/stripe/smokescreen/archive/${version}.tar.gz",
    tarball_prefix => "smokescreen-${version}",
  }

  exec { 'compile smokescreen':
    command     => "${zulip::golang::bin} build -o ${bin}",
    cwd         => $dir,
    # GOCACHE is required; nothing is written to GOPATH, but it is required to be set
    environment => ['GOCACHE=/tmp/gocache', 'GOPATH=/root/go'],
    creates     => $bin,
    require     => [
      Zulip::External_Dep['golang'],
      Zulip::External_Dep['smokescreen-src'],
    ],
  }
  unless $::operatingsystem == 'Ubuntu' and $::operatingsystemrelease == '18.04' {
    # Puppet 5.5.0 and below make this always-noisy, as they spout out
    # a notify line about tidying the managed file above.  Skip
    # on Bionic, which has that old version; they'll get tidied upon
    # upgrade to 20.04.
    tidy { '/usr/local/bin/smokescreen-*':
      path    => '/usr/local/bin',
      recurse => 1,
      matches => 'smokescreen-*',
      require => Exec['compile smokescreen'],
    }
  }

  $listen_address = zulipconf('http_proxy', 'listen_address', '127.0.0.1')
  file { "${zulip::common::supervisor_conf_dir}/smokescreen.conf":
    ensure  => file,
    require => [
      Package[supervisor],
      Exec['compile smokescreen'],
    ],
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('zulip/supervisor/smokescreen.conf.erb'),
    notify  => Service[supervisor],
  }
}
