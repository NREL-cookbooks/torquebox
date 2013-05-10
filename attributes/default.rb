default[:torquebox][:user] = "jboss-as"
default[:torquebox][:version] = "2.3.1"
default[:torquebox][:dir] = "/opt/torquebox"
default[:torquebox][:log_dir] = "/var/log/jboss-as"
default[:torquebox][:rbenv_version] = nil

default[:torquebox][:jboss_opts] = []
default[:torquebox][:append_java_opts] = []
default[:torquebox][:clustered] = false
default[:torquebox][:http_port] = nil
default[:torquebox][:max_threads] = nil
default[:torquebox][:bind_ip] = nil
