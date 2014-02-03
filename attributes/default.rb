default[:torquebox][:version] = "3.0.2"
default[:torquebox][:user] = "torquebox"
default[:torquebox][:dir] = "/opt/torquebox"
default[:torquebox][:conf_dir] = "/etc/torquebox"
default[:torquebox][:log_dir] = "/var/log/torquebox"
default[:torquebox][:rbenv_version] = nil

default[:torquebox][:jboss_opts] = []
default[:torquebox][:append_java_opts] = []
default[:torquebox][:clustered] = false
default[:torquebox][:http_port] = nil
default[:torquebox][:max_threads] = nil
default[:torquebox][:bind_ip] = nil

default[:torquebox][:clustered] = false
default[:torquebox][:multicast] = false

default[:torquebox][:backstage][:version] = "1.1.0"
default[:torquebox][:backstage][:username] = "torquebox"
default[:torquebox][:backstage][:password] = nil
