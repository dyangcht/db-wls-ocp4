# Create a database instance
oc new-project database-namespace
# Prepare pull image secrets
oc create secret docker-registry regsecret \
    --docker-server=container-registry.oracle.com \
    --docker-username='yangorcl@gmail.com' \
    --docker-password='Pass!@#w0rd' \
    --docker-email='yangorcl@gmail.com'

# working directory /Users/dyangcht/tmp/weblogic-kubernetes-operator/kubernetes/samples/scripts/create-weblogic-domain/domain-home-in-image
# Create a db instance
oc create -f db.yaml

# Expose svc to public
oc expose rs database-bddb98bfb --port=1521 --type=LoadBalancer

# Internal database service name
database.database-namespace.svc.cluster.local:1521

# Prepare user, tables and data
# Connect to db via sqlplus, SQLDeveloper or JDeveloper
sql> create user c##hr identified by Welcome#1;
sql> grant resource,connect to c##hr;
sql> ALTER USER c##hr quota unlimited on USERS;
# Run hr_30.sql under Downloads/RedHat
sql> @HR_30.sql
# Insert data
sql> insert into jobs values('1','Manager',100,300);
sql> insert into jobs values('2','Director',150,400);



### build weblogic on OCP
# Clone weblogic operator from github
git clone --branch v3.2.1 https://github.com/oracle/weblogic-kubernetes-operator
cd weblogic-kubernetes-operator
# don’t need to pull images to local
docker pull ghcr.io/oracle/weblogic-kubernetes-operator:3.2.1
docker pull container-registry.oracle.com/middleware/weblogic:12.2.1.4
kubectl create namespace sample-weblogic-operator-ns
kubectl create serviceaccount -n sample-weblogic-operator-ns sample-weblogic-operator-sa
helm install sample-weblogic-operator kubernetes/charts/weblogic-operator \
  --namespace sample-weblogic-operator-ns \
  --set image=ghcr.io/oracle/weblogic-kubernetes-operator:3.2.1 \
  --set serviceAccount=sample-weblogic-operator-sa \
  --set "enableClusterRoleBinding=true" \
  --set "domainNamespaceSelectionStrategy=LabelSelector" \
  --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
  --wait
####
NAME: sample-weblogic-operator
LAST DEPLOYED: Sun Apr 18 13:02:55 2021
NAMESPACE: sample-weblogic-operator-ns
STATUS: deployed
REVISION: 1
TEST SUITE: None
####
kubectl get pods -n sample-weblogic-operator-ns
####
NAME                                READY   STATUS    RESTARTS   AGE
weblogic-operator-b86b89c75-jzpb4   1/1     Running   0          76s
####

# Create a namespace for weblog domain
kubectl create namespace sample-domain1-ns
kubectl label ns sample-domain1-ns weblogic-operator=enabled
# Create a secret for the weblogic admin
kubernetes/samples/scripts/create-weblogic-domain-credentials/create-weblogic-credentials.sh \
  -u weblogic -p welcome1 -n sample-domain1-ns -d sample-domain1
# Prepare a create script
cd kubernetes/samples/scripts/create-weblogic-domain/domain-home-in-image
cp create-domain-inputs.yaml myinputs.yaml
vi myinputs.yaml
### Change the following parameters
domainUID: sample-domain1
weblogicCredentialsSecretName: sample-domain1-weblogic-credentials
namespace: sample-domain1-ns
domainHomeImageBase: container-registry.oracle.com/middleware/weblogic:12.2.1.4
###
# Create a domain
./create-domain.sh -i myinputs.yaml -o output -u weblogic -p welcome1 -e
# Cannot startup normally
# Edit the domain.yaml  -- put it under mydomain/domain.yaml
vi outputs/weblogic-domains/sample-domain1/domain.yaml
### Change the following parameters
image: "dyangcht/12213-domain-with-app:v1.1"
###
# The original one is like ⇒ image: "domain-home-in-image:12.2.1.4"
# Recreate the domain
oc delete -f outputs/weblogic-domains/sample-domain1/domain.yaml
oc apply -f outputs/weblogic-domains/sample-domain1/domain.yaml

# Put an application in WLS domain
jar -cvf archive.zip hrapp2.ear
docker build --build-arg APPLICATION_NAME=hrapp2 --build-arg APPLICATION_PKG=archive.zip -t dyangcht/12213-domain-with-app:v1.1 .

### Dockerfile
FROM domain-home-in-image:12.2.1.4	# generated by the create-domain.sh
MAINTAINER Monica Riccelli <monica.riccelli@oracle.com>

ARG APPLICATION_NAME="${APPLICATION_NAME:-sample}"
ARG APPLICATION_PKG="${APPLICATION_PKG:-archive.zip}"

# Define variables
ENV APP_NAME="${APPLICATION_NAME}" \
    APP_FILE="${APPLICATION_NAME}.ear" \
    APP_PKG_FILE="${APPLICATION_PKG}"

# Copy files and deploy application in WLST Offline mode
COPY container-scripts/* /u01/oracle/
COPY $APP_PKG_FILE /u01/oracle/

RUN cd /u01/oracle & $JAVA_HOME/bin/jar xf /u01/oracle/$APP_PKG_FILE && \
    /u01/oracle/deployAppToDomain.sh

# Define default command to start bash.
CMD ["startAdminServer.sh"]
###

# Sample Application URL
http://sample-domain1-cluster-cluster-1-sample-domain1-ns.apps.cluster-050a.sandbox1092.opentlc.com/hrapp2/hr.jsp

# Admin Console URL
http://sample-domain1-admin-server-sample-domain1-ns.apps.cluster-050a.sandbox1092.opentlc.com/console/
