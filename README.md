# LLaVA on OpenShift

This repo sets up [LLaVA](https://github.com/haotian-liu/LLaVA) running in [Ollama](https://github.com/ollama/ollama) on OpenShift.

It is meant to be deployed on top of the `NVIDIA GPU Operator OCP4 Workshop` demo cluster.

To deploy, run

	make deploy

After the ollama pod comes up, test it with:

01. Set the `purl` environment variable to the URL of the picture you want

		export purl=https://dummy.server/path/to/image.jpg

01. Ensure that we can reach ollama

		export proj=demo

		export ourl=http://$(oc get -n $proj route/ollama -o jsonpath='{.spec.host}')

		curl $ourl

01. Convert the picture to Base64

		curl $ourl

		export photo="$(curl $purl | base64)"

		echo $photo | head -c 10

01. Send a query to ollama

		curl ${ourl}/api/generate -d \
		'{
		  "model":"llava",
		  "prompt":"What is in this picture?",
		  "images":["'"$(echo -n $photo)"'"]
		}' | jq -r .response


## Resources

*   [Ollama Helm Chart](https://github.com/otwld/ollama-helm/)
*   [Running LLaVA in Ollama](https://ollama.com/library/llava)
