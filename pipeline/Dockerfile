FROM continuumio/miniconda3:4.10.3-alpine

# First, we install the necessary packages.
COPY conda-pkgs.txt .
RUN conda install --file conda-pkgs.txt

# Then, we put our script in the image.
# Any changes to our script will incur a redoing of every next steps,
# so it is best to do this step as late as possible.
COPY *.py /app/
