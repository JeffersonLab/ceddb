# ceddb
This repository contains the scripts necessary to create the CEBAF Element Database schema.

Detailed instructions regarding the scripts and their usage at JLAB can be found in the PDF documents in the doc directory.


## Build the base image

```shell
git clone https://github.com/JeffersonLab/ceddb.git

# Build the container
cd ceddb/docker
docker build -t jeffersonlab/ceddb:V.v -f docker/Dockerfile .  # where V.v is Major.minor version

# Run the container (optional)
docker run -d --name ceddb jeffersonlab/ceddb:V.v

# Connect to the container (optional)
docker exec -it ceddb /bin/bash
```

## Build the populated image

```shell

# First create the base image above
# Then make sure the Dockerfile-populate references the version on its
# first line:  FROM jeffersonlab/ceddb:V.v
docker build -t jeffersonlab/ceddb:V.v-populate -f docker/Dockerfile-populate .  # where V.v is Major.minor version

# The first time the image is executed it will install oracle, create CED schemas, and import
# data from a dump file.
docker run --rm --name ceddb jeffersonlab/ceddb:V.v-populate

# After the database is installed, use the docker commit to save the state of the image with
# the -populated version tag.
docker commit ceddb jeffersonlab/ceddb:V.v-populated
```


## Push the base and populated images to dockerhup

