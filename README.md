# Integration with Gitlab CI/CD

- Integration of github with gitlab requires 4-5 simple steps. Well documented here https://docs.gitlab.com/ee/ci/ci_cd_for_external_repos/github_integration.html.
- After integration is done and this repo is mirrored to the new one on Gitlab, use the .gitlab-ci.yml to define the flow of the pipeline.
- gitlab project(mirrored to this github repo) where the CI/CD is set up is https://gitlab.com/binid/node_api (please request access if needed)

# Add Kubernetes cluster to the Gitlab

## Kubernetes side
- Get API URL & CA certificate. Create Service Token to authenticate with the cluster.
- API URL:
`kubectl cluster-info | grep -E 'Kubernetes master|Kubernetes control plane' | awk '/http/ {print $NF}'`
- CA certificate(you can use the default):
`kubectl get secret <default-token-xxxxx> -o jsonpath="{['data']['ca\.crt']}" | base64 --decode`
- Service Token:
First create a gitlab service account with cluster-admin role.
```
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gitlab-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: gitlab
    namespace: kube-system
```
Then, retrieve the Token for the gitlab service account by running this command and copy the token,
`kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep gitlab | awk '{print $1}')`


## Gitlab side
- On the new Gitlab repo(mirrored from the github repo), go to `Infrastructure` --> `kubernetes clusters` to add a project level kubernetes cluster. Add Cluster's `name`, `API URL`, `CA certificate` and `service token`.

# Integration with Gitlab image registry

## Gitlab side
- Deploy token is generated to allow access to packages, your repository, and registry images
- Pull-secret is generated using the username and token from the deploy token. Generated base64 string value is:
`eyJhdXRocyI6eyJyZWdpc3RyeS5naXRsYWIuY29tIjp7ImF1dGgiOiJaMmwwYkdGaUsyUmxjR3h2ZVMxMGIydGxiaTAxTURrMU5EZzZTelJtUm5rMmVWTnlSWGhIUm1aMFYzcGpMVXc9In19fQ==`

## Kubernetes side
- Use the above base64 string to create a secret of type 'kubernetes.io/dockerconfigjson' which will be used to pull images from the gitlab image registry. Make sure the imagePullSecrets in deployment yaml is identical to this secret name value. Run this yaml file to create the secret,
```
kind: Secret
apiVersion: v1
metadata:
  name: gitlab-pull-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6eyJyZWdpc3RyeS5naXRsYWIuY29tIjp7ImF1dGgiOiJaMmwwYkdGaUsyUmxjR3h2ZVMxMGIydGxiaTAxTURrMU5EZzZTelJtUm5rMmVWTnlSWGhIUm1aMFYzcGpMVXc9In19fQ==
```

# Dockerfile & DB endpoint

- Dockerfile is written, there was some module path error which is edited. 
- PORT is defined in the Dockerfile.
- DATABASE_URL is passed as an environment variable in the deployment yaml file so that we have the flexibility to change the DATABASE_URL in Kubernetes secrets(no need of rebuilding the image, just requires rollout restarting the nodejs pod after editing DATABASE_URL secret value).
- This file creates the secret in staging & production namespaces;
```
apiVersion: v1
kind: Secret
metadata:
  name: staging-secrets
  namespace: staging
stringData:
  DATABASE_URL: https://staging.dburl
---
apiVersion: v1
kind: Secret
metadata:
  name: production-secrets
  namespace: production
stringData:
  DATABASE_URL: https://prod.dburl
```

# Workflow/CI/CD

- .gitlab-ci.yml defines the workflow. I used two branches, master to production namespace(k8s needs to have production namespace created) & staging to staging namespace(assumed staging namespace exists).
I created the staging branch out of master. 
- Developers will branch off from staging branch and create new branches to make modification to the code. Once done, when merged to staging, pipeline will be triggered and docker image will be build & deployment to staging namespace/environment will take place(it is automatic, no need of manual approval as it is a staging environment).
- To deploy to production environment/namespace, staging branch needs to be merged to master branch. This will trigger the pipeline, docker image will be build & deployment to production namespace will follow(this has a manual approval stage just before deployment as this is a production environment).
- For tagging images, I used `${CI_COMMIT_REF_SLUG}` among others as it contains git branch name.


# Apologies

- Big appologies for not delivering a complete project as I am having a very busy work schedule since last week. I would have provisioned a Kubernetes cluster and tested the whole CI/CD if I have time, I am sure there might be some missing things from the config files. I did this work in my little spare time I have & I tried to put what needs to be done in this read me file.
