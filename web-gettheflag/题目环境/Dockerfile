FROM elice/python-nginx:3.10


RUN apt-get update && apt-get install -y \
    golang  python3-pip\
    && python3 -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple flask requests \
    && rm -rf /var/www/html/* \
    && mkdir /var/www/html/login \
    && usermod -s /bin/bash www-data

COPY ./src/html/ /var/www/html/
COPY ./src/nginx.conf /etc/nginx/nginx.conf
COPY ./src/flag /flag
COPY ./src/run.sh /run.sh


RUN chown root:root /flag \
    && chmod 744 /flag \
    && chown -R www-data:www-data /var/www/ \
    && chmod -R 755 /var/www/html/

cmd ["bash", "-c", "/run.sh"]