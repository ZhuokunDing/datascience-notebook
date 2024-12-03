#! /bin/bash
docker build . -t at-docker:5000/datascience-notebook:cuda12.4-python3.12
docker push at-docker:5000/datascience-notebook:cuda12.4-python3.12

