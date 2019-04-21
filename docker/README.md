### Setup with docker

Use docker command to pull image:

``` bash
docker pull ciriethereum/ciri
```

Or you can use our prepared rake tasks if you're not familiar with docker:

clone repo and submodules

``` bash
git clone --recursive https://github.com/ciri-ethereum/ciri.git
cd ciri
```

make sure we have installed docker, ruby and rake
``` bash
# make sure we have installed docker, ruby and rake
docker -v
gem install rake
```

#### Pull docker image

``` bash
# pull Ciri docker image
rake docker:pull
```

#### Run tests in docker
``` bash
# run tests
rake docker:spec

# run specific component related tests
rake docker:spec[component_name]
```

#### Other usages
``` bash
# open a shell for developing
rake docker:shell

# build Ciri docker image from current source (it will take a few minutes)
rake docker:build

# type 'rake -T' see other supported tasks 
rake -T
``` 

