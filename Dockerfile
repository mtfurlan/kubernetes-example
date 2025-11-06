FROM nginx
RUN echo "<html><body>hello world</body></html>" > /usr/share/nginx/html/index.html
