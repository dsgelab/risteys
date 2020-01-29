workflow RisteysPipelineMain {
	# Ontology
	File endpoint_mapping
	File EFO
	call ontology {
		input: endpoint_mapping=endpoint_mapping, efo=EFO
	}
}

task ontology {
	File endpoint_mapping
	File efo
	String soutput

	command {
		python3 /app/build_ontology.py ${endpoint_mapping} ${efo} ${soutput}
	}

	output {
		File out = "${soutput}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "2 GB"
		zones: "europe-west1-b"
		preemptible: 1
		noAddress: true
	}
}
