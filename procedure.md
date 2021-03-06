# Create a database instance
```
oc new-project database-namespace
```
## Prepare pull image secrets
```
oc create secret docker-registry regsecret \
    --docker-server=container-registry.oracle.com \
    --docker-username='yourname@gmail.com' \
    --docker-password='Password' \
    --docker-email='yourname@gmail.com'
```
## Create a db instance
```
cd database
# oc create user orcl
# oc adm policy add-scc-to-user anyuid orcl
# oc create -f db.yaml --as=orcl
oc adm policy add-scc-to-user anyuid -z default
oc create -f db.yaml
# Take > 10 mins if you're using OVN
```

## Expose svc to public
```
oc get rs
oc expose rs database-<bddb98bfb> --port=1521 --type=LoadBalancer
```
Get the Load balancer
```
oc get svc
```
Forward the port to local port, 1521(local/from):1521(remote/to)
```
oc port-forward pod/database-58884bccbd-42j5f 1521:1521
```

## Internal database service name
``` database.database-namespace.svc.cluster.local:1521 ```

## Prepare user, tables and data
## Connect to db via sqlplus, SQLDeveloper or JDeveloper
```
sql> create user c##hr identified by Welcome#1;
sql> grant resource,connect to c##hr;
sql> ALTER USER c##hr quota unlimited on USERS;
```
Log into the DB using the new user you just created "c##hr"

## Run hr_30.sql under Downloads/RedHat
``` sql> @database/HR_30.sql ```
## Insert data
```
sql> insert into jobs values('1','Manager',100,300);
sql> insert into jobs values('2','Director',150,400);
```


# build weblogic on OCP
## Clone weblogic operator from github
```
git clone --branch v3.2.1 https://github.com/oracle/weblogic-kubernetes-operator
cd weblogic-kubernetes-operator
```
## don’t need to pull images to local
<p>
docker pull ghcr.io/oracle/weblogic-kubernetes-operator:3.2.1 <br/>
docker pull container-registry.oracle.com/middleware/weblogic:12.2.1.4 <br/>


```
# kubectl create namespace sample-weblogic-operator-ns
# kubectl create serviceaccount -n sample-weblogic-operator-ns sample-weblogic-operator-sa
$ cd ..
$ oc new-project sample-weblogic-operator-ns
$ oc create serviceaccount -n sample-weblogic-operator-ns sample-weblogic-operator-sa
$ helm install sample-weblogic-operator kubernetes/charts/weblogic-operator \
  --namespace sample-weblogic-operator-ns \
  --set image=ghcr.io/oracle/weblogic-kubernetes-operator:3.2.1 \
  --set serviceAccount=sample-weblogic-operator-sa \
  --set "enableClusterRoleBinding=true" \
  --set "domainNamespaceSelectionStrategy=LabelSelector" \
  --set "domainNamespaceLabelSelector=weblogic-operator\=enabled" \
  --wait
```
### Response
```
NAME: sample-weblogic-operator
LAST DEPLOYED: Sun Apr 18 13:02:55 2021
NAMESPACE: sample-weblogic-operator-ns
STATUS: deployed
REVISION: 1
TEST SUITE: None
```
### Checking status
```
oc get pods -n sample-weblogic-operator-ns
```
### Response
```
NAME                                READY   STATUS    RESTARTS   AGE
weblogic-operator-b86b89c75-jzpb4   1/1     Running   0          76s
```

## Create a namespace for weblogic domain
```
# kubectl create namespace sample-domain1-ns
oc new-project sample-domain1-ns
oc label ns sample-domain1-ns weblogic-operator=enabled
```
## Create a secret for the weblogic admin
```
$ kubernetes/samples/scripts/create-weblogic-domain-credentials/create-weblogic-credentials.sh \
  -u weblogic -p welcome1 -n sample-domain1-ns -d sample-domain1
$ oc get secret sample-domain1-weblogic-credentials
```
## Response
```
NAME                                  TYPE     DATA   AGE
sample-domain1-weblogic-credentials   Opaque   2      48s
```
## Prepare a create script
```
cd kubernetes/samples/scripts/create-weblogic-domain/domain-home-in-image
cp create-domain-inputs.yaml myinputs.yaml
vi myinputs.yaml
```
### Change the following parameters
```
domainUID: sample-domain1
weblogicCredentialsSecretName: sample-domain1-weblogic-credentials
namespace: sample-domain1-ns
domainHomeImageBase: container-registry.oracle.com/middleware/weblogic:12.2.1.4
```
## Create a domain
Before run it make sure the dockerd is running. It creates an image "domain-home-in-image:12.2.1.4"
``` ./create-domain.sh -i myinputs.yaml -o output -u weblogic -p welcome1 -e ```
## Cannot startup normally
## Edit the domain.yaml  -- put it under mydomain/domain.yaml
``` vi outputs/weblogic-domains/sample-domain1/domain.yaml ```
### Change the following parameters
``` image: "dyangcht/12213-domain-with-app:v1.1"  ```
###
## The original one is like ⇒ image: "domain-home-in-image:12.2.1.4"
## Recreate the domain
You can see the sample ```domain.yaml``` under the mydomain <br/>
You can apply it directly if your namespaces are the same as the document <br/>
```
oc delete -f outputs/weblogic-domains/sample-domain1/domain.yaml
oc apply -f outputs/weblogic-domains/sample-domain1/domain.yaml
```
## Response snippet
```
NAME                                READY   STATUS              RESTARTS   AGE
sample-domain1-introspector-dsw5j   0/1     ContainerCreating   0          24s
sample-domain1-introspector-dsw5j   1/1     Running             0          46s
sample-domain1-introspector-dsw5j   0/1     Completed           0          58s
sample-domain1-introspector-dsw5j   0/1     Terminating         0          58s
sample-domain1-introspector-dsw5j   0/1     Terminating         0          58s
sample-domain1-admin-server         0/1     Pending             0          0s
sample-domain1-admin-server         0/1     Pending             0          0s
sample-domain1-admin-server         0/1     Pending             0          0s
sample-domain1-admin-server         0/1     ContainerCreating   0          0s
sample-domain1-admin-server         0/1     ContainerCreating   0          2s
sample-domain1-admin-server         0/1     Running             0          45s
sample-domain1-admin-server         1/1     Running             0          75s
sample-domain1-managed-server1      0/1     Pending             0          0s
sample-domain1-managed-server1      0/1     Pending             0          0s
sample-domain1-managed-server1      0/1     ContainerCreating   0          0s
sample-domain1-managed-server1      0/1     ContainerCreating   0          0s
sample-domain1-managed-server2      0/1     Pending             0          0s
sample-domain1-managed-server2      0/1     Pending             0          0s
sample-domain1-managed-server2      0/1     Pending             0          0s
```
<p/>

### Checking WebLogic Services
```
$ oc get svc -n sample-domain1-ns
```

### Reponse
```
NAME                               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)              AGE
sample-domain1-admin-server        ClusterIP   None             <none>        30012/TCP,7001/TCP   3m32s
sample-domain1-cluster-cluster-1   ClusterIP   172.30.114.136   <none>        8001/TCP             2m17s
sample-domain1-managed-server1     ClusterIP   None             <none>        8001/TCP             2m17s
sample-domain1-managed-server2     ClusterIP   None             <none>        8001/TCP             2m17s
```
### Expose cluster services
```
$ oc expose svc sample-domain1-cluster-cluster-1
```

<p/>

## Put an application in WLS domain
```
cd weblogic-kubernetes-operator/mydomain/hrapp2/deploy
jar -cvf archive.zip hrapp2.ear
docker build --build-arg APPLICATION_NAME=hrapp2 --build-arg APPLICATION_PKG=archive.zip -t dyangcht/12213-domain-with-app:v1.1 .
docker push dyangcht/12213-domain-with-app:v1.1
```

### Dockerfile
You can build your own image using the Dockerfile
```
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
```

### Sample Application URL
``` http://sample-domain1-cluster-cluster-1-sample-domain1-ns.apps.cluster-050a.sandbox1092.opentlc.com/hrapp2/hr.jsp ```

### Admin Console URL
``` http://sample-domain1-admin-server-sample-domain1-ns.apps.cluster-050a.sandbox1092.opentlc.com/console/ ```


### Run SQLDeveloper on the MacOS
$INSTALLED_DIR/SQLDeveloper.app/Contents/Resources/sqldeveloper/sqldeveloper/bin/sqldeveloper

### RHPDS information

DB URL: a99cafa9ac3c2427f8f0ff910b4cbe2b-549459842.us-east-2.elb.amazonaws.com <br/>
DB SID: OraDoc <br/>

## OpenTracing and Jaeger

```
wget https://raw.githubusercontent.com/jaegertracing/jaeger-openshift/master/all-in-one/jaeger-all-in-one-template.yml
```
Change some values like Deployment's version and selector
```
vi jaeger-all-in-one-template.yml
```
Apply it
```
oc project threescale-1ff4
oc process -f jaeger-all-in-one-template.yml| oc create -f -
oc create configmap jaeger-config --from-file=jaeger_config.json
oc set volume dc/apicast-staging --add -m /tmp/jaeger/ --configmap-name jaeger-config
oc set env dc/apicast-staging OPENTRACING_TRACER=jaeger OPENTRACING_CONFIG=/tmp/jaeger/jaeger_config.json
```

### Reference
https://itnext.io/adding-opentracing-support-to-apicast-api-gateway-a8e0a38347d2 <br/>
http://jaeger-query-threescale-1ff4.apps.shared-na4.na4.openshift.opentlc.com/search

WORKDIR: /Users/dyangcht/opt/redhat/ocp4/sharing/weblogic-kubernetes-operator
