FROM ubuntu:18.04

# Expose ports
EXPOSE 8000
EXPOSE 8787
EXPOSE 3838

# Set variables
ENV NEWUSER=newuser
ENV PASSWD=password
RUN useradd -ms /bin/bash $NEWUSER
RUN echo 'newuser:password' | chpasswd
RUN adduser $NEWUSER sudo

# Install base packages
RUN apt-get update
RUN DEBIAN_FRONTEND=noninteractive apt-get -qq install tzdata apt-utils
RUN ln -fs /usr/share/zoneinfo/Africa/Johannesburg /etc/localtime
RUN dpkg-reconfigure --frontend noninteractive tzdata

RUN apt-get update
RUN apt-get install -y \
    git \
    cron \
    sudo \
    nano \
    wget

# Install jupyterhub dependencies
RUN apt-get install -y \
    nodejs \
    htop \
    python3-pip \
    npm
    
RUN npm cache clean -f
RUN npm -v

# Install jupyterhub
RUN npm install -g configurable-http-proxy
RUN pip3 install jupyterhub
RUN pip3 install --upgrade notebook

RUN jupyterhub --generate-config

RUN pip3 install jupyterlab
RUN jupyter serverextension enable --py jupyterlab --sys-prefix
RUN jupyter labextension install @jupyterlab/hub-extension

RUN sed -i "/c.Authenticator.admin_users/c\c.Authenticator.admin_users = {\'$NEWUSER\'}" /jupyterhub_config.py
RUN sed -i "/c.Spawner.default_url/c\c.Spawner.default_url = '/lab'" /jupyterhub_config.py
RUN sed -i "/c.Spawner.cmd/c\c.Spawner.cmd = ['jupyter-labhub']" /jupyterhub_config.py
RUN mkdir /etc/jupyterhub
RUN mv /jupyterhub_config.py /etc/jupyterhub/
RUN chown root:root /etc/jupyterhub/jupyterhub_config.py
RUN chmod 0644 /etc/jupyterhub/jupyterhub_config.py

# Install RStudio dependencies
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
RUN echo "# CRAN Repo" | sudo tee -a /etc/apt/sources.list
RUN echo "deb https://cloud.r-project.org/bin/linux/ubuntu bionic-cran35/" | sudo tee -a /etc/apt/sources.list

RUN apt-get install r-base -y
RUN apt-get install gdebi-core dpkg -y
RUN wget https://download2.rstudio.org/rstudio-server-1.1.456-amd64.deb -O rs-latest.deb
RUN gdebi -n rs-latest.deb
RUN rm -f rs-latest.deb

# Install miktex
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D6BC243565B2087BC3F897C9277A7293F59E4889
RUN echo "deb http://miktex.org/download/ubuntu bionic universe" | sudo tee /etc/apt/sources.list.d/miktex.list
RUN apt-get update
RUN apt-get install miktex -y
 
RUN apt-get install -y \
    pandoc \
    pandoc-citeproc

# Install and setup shiny
RUN wget "https://download3.rstudio.org/ubuntu-14.04/x86_64/shiny-server-1.5.7.907-amd64.deb" -O ss-latest.deb
RUN gdebi -n ss-latest.deb
RUN rm -f ss-latest.deb
RUN R -e "install.packages(c('shiny', 'rmarkdown'), repos='https://cran.rstudio.com/')" 
RUN cp -R /usr/local/lib/R/site-library/shiny/examples/* /srv/shiny-server/
RUN rm -rf /var/lib/apt/lists/*
#COPY shiny-customized.config /etc/shiny-server/shiny-server.conf

# Install tini to run entrypoint command
ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "--"]

RUN echo "shiny-server &" >> /run.sh
RUN echo "rstudio-server start" >> /run.sh
RUN echo "jupyterhub -f /etc/jupyterhub/jupyterhub_config.py" >> /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]

#USER $NEWUSER
#WORKDIR /home/$NEWUSER

# ISSUES #
# RUN MORE SECURELY, NOT AS ROOT
# DROP DOWN PRIVILEGES TO UNPRIVILEGED USER
# ALLOW FOR PASSWORD CHANGE FOR ADMIN USER
# ADD ENV VARIABLES TO CHOOSE WHAT SERVICES TO EXPOSE
