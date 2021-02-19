
deploy:        ## Deploy current manifests to configured cluster
	-bin/deploy

teardown:        ## Delete all monitoring stack resources from configured cluster
	-bin/teardown