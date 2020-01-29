FROM python:3

# Don't copy the Python scripts here as it would make the whole
# container being rebuilt each time there is a change in the scripts
COPY requirements.txt /app/

RUN pip install -r /app/requirements.txt
COPY *.py /app/
