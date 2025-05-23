#! /bin/bash
docker build . -t registry.atlab.stanford.edu:5000/datascience-notebook:cuda11.8-python3.12-torch2.7.0
docker push registry.atlab.stanford.edu:5000/datascience-notebook:cuda11.8-python3.12-torch2.7.0

