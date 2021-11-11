FROM continuumio/miniconda3:4.10.3

# First, we install the necessary packages.
COPY conda-pkgs.txt .
# Install mamba for easier and faster dependency solving
RUN conda install -c conda-forge -n base mamba
RUN mamba install -c conda-forge -c bioconda -n base --file conda-pkgs.txt

# Then, we put our script in the image.
# Any changes to our script will incur a redoing of every next steps,
# so it is best to do this step as late as possible.
COPY *.py /app/
