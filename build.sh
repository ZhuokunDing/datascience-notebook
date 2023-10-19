#! /bin/bash
docker build . -t at-docker:5000/datascience-notebook:cuda11.8-python3.10-torch2
docker push at-docker:5000/datascience-notebook:cuda11.8-python3.10-torch2

