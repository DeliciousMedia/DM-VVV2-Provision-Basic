# DM-VVV2-Provision-Basic
Provision scripts to setup a copy of WordPress along with a blank theme ready to begin a new project.

If you don't already have a vvv-custom.yml, create it by copying _~/vagrant-local/vvv-config.yml_ to _~/vagrant-local/vvv-custom.yml_.

Add the following lines to the ``sites:`` section:

```
  excitingproject:
    nginx_upstream: php71
    repo: https://github.com/DeliciousMedia/DM-VVV2-Provision-Basic.git
    hosts:
      - excitingproject.dev
```

If it isn't there already, include PHP 7.1 by adding `` - php71`` under the ``utilities:`` section.

Start the machine with ``vagrant up --provision`` or if it is already running, provision using ``vagrant reload --provision``.
