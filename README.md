# Directions

ALL files at this level SHOULD be executed on the management machine! If you have just downloaded Soveregin Stack, run `install.sh` to install all the dependencies required by Sovereign Stack scripts.

# Dockerfile

If you want to run the Sovereign Stack management machine activities inside a docker container, you can do so by 1) building the image and 2) running the resulting sovereign stack docker container:

## Building

docker build -t sovereign-stack .

## Running

docker run -it sovereign-stack \
  -v "$HOME/.sites/domain.tld"