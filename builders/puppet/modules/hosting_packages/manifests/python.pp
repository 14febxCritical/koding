
class hosting_packages::python {
    
    # modules installed from RPM
    $python_modules = ["pymongo-gridfs",
                        "pymongo",
                        "python27-devel",
                        "python27-tools",
                        "MySQL-python",
                        "ipython",
         		        "python-flup.noarch",
                        "python-virtualenv",
                        "python-setuptool",
                        "python-docutils",
                      ]
    
    package { ["python","python27"]:
        ensure => installed,
    }

    exec { "pip":
        command => '/usr/bin/easy_install pip',
        unless => "/usr/bin/which pip",
    }
    
    $non_rpm_modules = ["django"]

    package { $non_rpm_modules:
        ensure => installed,
        provider => pip,
        require => [Package["python"],Exec['pip']],
        notify => Class["cloudlinux::cagefs_update"],
    }

    package { $python_modules:
        ensure => installed,
        require => [ Class["yumrepos::epel"], Package["python"], Class["yumrepos::koding"]],
        notify => Class["cloudlinux::cagefs_update"],
    }
}
