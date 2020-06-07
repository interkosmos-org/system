# Mission

A minimal shell scripting UX library. Makes your shell scripts look a little bit neat.

## Installation

1. Clone repository or add repository as a submodule
2. Add `source mission/mission.sh` to your shell script

## Usage

* `mission` describes a task
* `phase` declares what should be done

### Local example

```bash
#!/usr/bin/env bash

source mission/mission.sh

mission "update apt"
  phase apt update

mission "upgrade packages"
  phase apt upgrade -y
```

### Remote example

```bash
#!/usr/bin/env bash

source mission/mission.sh

mission "define ssh transport"
  transport="ssh -l root 192.168.1.100"

mission "upgrade packages"
  phase $transport dnf update -y
```

## Contributing

1. Fork it (<https://github.com/interkosmos-org/mission/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Interkosmos](https://github.com/interkosmos-org) - creator and maintainer
