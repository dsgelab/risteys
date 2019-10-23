# no wheel for scipy on 3.8 yet
FROM python:3.7

RUN apt update && apt install -y libhdf5-dev
ADD requirements.txt .
RUN pip install -r requirements.txt
