FROM tomcat:10.1-jdk17-jammy

# Workdir for source files
WORKDIR /app

# Copy the project files
COPY . /app

# Create build directory and classes dir
RUN mkdir -p /app/build/web/WEB-INF/classes

# Sync web files (similar to robocopy in build-tools.ps1)
RUN cp -r /app/web/* /app/build/web/

# Find all Java source files and compile them
RUN find /app/src/java -name "*.java" > /app/sources.txt && \
    javac -encoding UTF-8 -g:none -nowarn -target 17 -source 17 \
    -cp "/app/web/WEB-INF/lib/*:/usr/local/tomcat/lib/*" \
    -d "/app/build/web/WEB-INF/classes" \
    @/app/sources.txt

# Deploy the built web app to Tomcat webapps
RUN rm -rf /usr/local/tomcat/webapps/* && \
    cp -r /app/build/web /usr/local/tomcat/webapps/Ban_Hoa_Qua_Online

ENV JAVA_OPTS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Dfile.client.encoding=UTF-8"
ENV CATALINA_OPTS="-Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8 -Dfile.client.encoding=UTF-8"

EXPOSE 8080
CMD ["catalina.sh", "run"]
