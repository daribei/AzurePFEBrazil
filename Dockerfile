FROM node:8.9

RUN  mkdir -p /opt/startup \
     && echo "root:Docker!" | chpasswd \
     && echo "cd /home" >> /etc/bash.bashrc \
     && apt-get update \
     && apt-get install --yes --no-install-recommends openssh-server

# configure startup

RUN rm -f /etc/ssh/sshd_config

RUN mkdir -p /tmp
COPY sshd_config /etc/ssh/

COPY ssh_setup.sh /tmp
RUN chmod -R +x /opt/startup \
   && chmod -R +x /tmp/ssh_setup.sh \
   && (sleep 1;/tmp/ssh_setup.sh 2>&1 > /dev/null) \
   && rm -rf /tmp/* \

ENV SSH_PORT 2222
EXPOSE 2222 8080

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN npm install pm2 -g

WORKDIR /usr/src/app

# Install app dependencies
# A wildcard is used to ensure both package.json AND package-lock.json are copied
# where available (npm@5+)

COPY package*.json ./
RUN npm install

# If you are building your code for production
# RUN npm ci --only=production
# Bundle app source

COPY . .

ENTRYPOINT ["/entrypoint.sh"]