# Interkosmos System

NixOS with GitOps orientation with Docker based build system.

## Installation

1. Install Docker
2. Clone repository

## Usage

### Build ISO image

```bash
./build.sh iso
``` 

### Build Scaleway image

```bash
# add your scaleway credentials and configuration to `scaleway/config.yaml`
echo "access_key: SCWMYACCESSKEY123456
secret_key: f5254b24-a8f4-11ea-865f-0242ac110002
default_organization_id: 0e5ac42a-a8f5-11ea-90ff-0242ac110002
default_region: fr-par
default_zone: fr-par-1" > scaleway/config.yaml

./build.sh scaleway
```

### Access build container

```bash
./build.sh bash
```

## Contributing

1. Fork it (<https://github.com/interkosmos-org/system/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Interkosmos](https://github.com/interkosmos-org) - creator and maintainer
