# kaito-sample-pr-reviewer
This repository is used to build and iterate on an Automated Pull Request (PR) Reviewer powered by Kubernetes AI Toolchain Operator (KAITO)! The KAITO-powered PR reviwer helps streamline code reviews by analyzing pull requests and leaving intelligent feedback automatically. As this repository is augmented with merged (and approved) code changes, the PR reviewer can be continuously tuned to provide better feedback on each newly submitted pull request.

✨ What can a KAITO-powered PR reviewer do?

🔍 Analyze PR content (title, description, code diffs)
💬 Comment on potential issues, improvements, security concerns, or missing context
🧠 Leverage KAITO  to review code quality, documentation, and style
🔄 Integrates with GitHub via Webhooks or GitHub Apps
📦 Easy to deploy to any cloud or local environment

## Getting Started

### Prerequisites
- go version v1.23.0+
- docker version 17.03+.
- kubectl version v1.11.3+.
- Access to a Kubernetes v1.11.3+ cluster.

### Deploy inference workspace
**Deploy inference workspace to the cluster**

```sh
kubectl apply -f workspace/inference/inference.yaml
```

**Wait until the inference workspace is ready**

```sh
kubectl get workspace,deploy,svc workspace-qwen-2-5-coder-32b-instruct
```

The output should look like this:
```sh
NAME                                                       INSTANCE                   RESOURCEREADY   INFERENCEREADY   JOBSTARTED   WORKSPACESUCCEEDED   AGE
workspace.kaito.sh/workspace-qwen-2-5-coder-32b-instruct   Standard_NC24ads_A100_v4   True            True                          True                 3d21h

NAME                                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/workspace-qwen-2-5-coder-32b-instruct   1/1     1            1           3d21h

NAME                                            TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/workspace-qwen-2-5-coder-32b-instruct   ClusterIP   10.0.44.41   <none>        80/TCP    3d21h
```

Test the inference workspace by sending a request to the inference service. You can use curl or any HTTP client to send a POST request to the inference service.
```sh
export CLUSTERIP=10.0.44.41
kubectl run -it --rm --restart=Never curl-test --image=curlimages/curl -- \
curl -X POST http://${CLUSTERIP}/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
		  "model": "qwen2.5-coder-32b-instruct",
		  "prompt": "What is kubernetes?",
		  "max_tokens": 50,
		  "temperature": 0
	}'
```

The output should look like this:
```sh
{"id":"cmpl-fc3b5835f966488692b98e58681d20a8","object":"text_completion","created":1747713069,"model":"qwen2.5-coder-32b-instruct","choices":[{"index":0,"text":" Kubernetes, often abbreviated as K8s, is an open-source container orchestration platform designed to automate the deployment, scaling, and management of containerized applications. It was originally developed by Google and is now maintained by the Cloud Native Computing Foundation (CN","logprobs":null,"finish_reason":"length","stop_reason":null,"prompt_logprobs":null}],"usage":{"prompt_tokens":5,"total_tokens":55,"completion_tokens":50,"prompt_tokens_details":null}}
```

### deploy pr-agent

> You can find more details about the pr-agent in pr-agent repo [here](https://github.com/qodo-ai/pr-agent).

```sh
kubectl apply -f pr-agent
```

Under the hood, it will deploy a deployment with configuration specified in the `pr-agent/gateway/httproute.yaml` file and a gateway to expose the pr-agent service to public internet.

> You may need to configure the network and grant permission before deploying the gateway, please refer to the [Azure Application Gateway for Containers documentation](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers) for more details.

The pr-agent will listen to the events from the GitHub webhook and respond to the events, such as `pull_request`, `push`, and `issue_comment`. It only allows the events from [kaito-sample-repo](https://github.com/Azure-Samples/kaito-sample-repo) repository. During handling the events, it will call the inference service we deployed by kaito in the same cluster to get the response and post the response to the GitHub issue or pull request.


### Deploy fine-tune workspace

**Deploy fine-tune workspace to the cluster**

> You need to prepare your own dataset and pack it into an image. We use `workspace/tuning/go-operator-reviewer-data.parquet` as an example, and we already packed it into an image `kaitosample.azurecr.io/go-operator-reviewer-data:0.0.1` and pushed it to the Azure Container Registry.

```sh
kubectl apply -f workspace/tuning/tuning.yaml
```

Under the hood, kaito will create a job to fine-tune the model with the dataset we provided. The job will run in the background and you can check the status of the job by running the following command:

```sh
k get job workspace-tuning-qwen
```
The output should look like this:
```sh
NAME                    STATUS     COMPLETIONS   DURATION   AGE
workspace-tuning-qwen   Complete   1/1           93m        20h
```

After the job is completed, kaito will pack the adapter and configuration files into a new image and push it to the Azure Container Registry. In our case, it will be `kaitosample.azurecr.io/go-operator-reviewer-data-adapter:0.0.1`.


### Deploy inference-with-adapter workspace

Once you have the adapter image, you can deploy the inference-with-adapter workspace to the cluster. The inference-with-adapter workspace will use the adapter image to load the adapter to the model.

```sh
kubectl apply -f workspace/inference/inference-with-adapter.yaml
```

You can check whether the adapter is loaded successfully by running the following command:

```sh
kubectl logs workspace-qwen-2-5-coder-32b-instruct-with-adapter-65bc558bxbzh | grep "LoRA adapter"
```

The output should look like this:
```sh
INFO 05-19 09:56:58 inference_api.py:116] Loading LoRA adapters from /mnt/adapter
INFO 05-19 10:01:26 [serving_models.py:185] Loaded new LoRA adapter: name 'qwen-32b-adapter', path '/mnt/adapter/qwen-32b-adapter'
```

Now we have two inference workspaces, one is the original workspace and the other is the workspace with adapter. 
```sh
kubectl get pods | grep workspace-qwen-2-5-coder
workspace-qwen-2-5-coder-32b-instruct-66dfdbdc78-vpzkb            1/1     Running     0          3d21h
workspace-qwen-2-5-coder-32b-instruct-with-adapter-65bc558bxbzh   1/1     Running     0          18h
```

You can now use your own test tool to compare the two workspaces to see if the workspace with adapter is better than the original one. 
