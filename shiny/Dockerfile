FROM rocker/shiny:4.4

RUN install2.r --error \
    bslib \
    ggplot2 \
    dplyr \
    scales \
    htmltools \
    tibble

COPY app.R /srv/shiny-server/
COPY shiny-server.conf /etc/shiny-server/shiny-server.conf

EXPOSE 3838

CMD ["/usr/bin/shiny-server"]
