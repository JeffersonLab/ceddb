# This Docker file builds a populated
FROM gvenzl/oracle-xe:18-full

ENV ORACLE_PASSWORD='dflTPassWD'
ENV CED3_OWNER=${ORACLE_PASSWORD}
ENV CED3_DEVL=${ORACLE_PASSWORD}
ENV CED3_OPS=${ORACLE_PASSWORD}
ENV CED3_HIST=${ORACLE_PASSWORD}

# Put init scripts into place
COPY ./run/var/oracle/initdb/* /container-entrypoint-initdb.d

# Directory to be used for importing data
RUN mkdir /opt/oracle/oradata/impdb
