name             'torquebox'
maintainer       'NREL'
maintainer_email 'nick.muerdter@nrel.gov'
license          'All rights reserved'
description      'Installs/Configures torquebox'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.1.0'

depends "hostsfile"
depends "java"
depends "openssl"
depends "rbenv"
