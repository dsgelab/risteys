workflow RisteysPipelineMain {
	# Ontology
	File endpoint_mapping
	File EFO
	String ontology_output

	# FinnGen data
	File fg_minimum_data
	File fg_first_events
	File fg_longit
	File fg_endpoint_defs
	File fg_samples

	String qc_output
	String dense_output
	String hdf_output
	String stats_hdf
	String stats_json

	call ontology {
		input:
			endpoint_mapping=endpoint_mapping,
			efo=EFO,
			soutput=ontology_output
	}

	call QC {
		input:
			fg_minimum_data=fg_minimum_data,
			fg_first_events=fg_first_events,
			fg_longit=fg_longit,
			soutput=qc_output
	}

	call densify_first_events {
		input:
			fg_first_events=fg_first_events,
			longit_transient=QC.out,
			dense_output=dense_output
	}

	call build_input {
		input:
			fg_longit=densify_first_events.out_longit_transient,
			fg_minimum_data=fg_minimum_data,
			fg_endpoint_defs=fg_endpoint_defs,
			fg_samples=fg_samples,
			dense_output=densify_first_events.out,
			hdf_output=hdf_output
	}

	call aggregate_stats {
		input:
			input_hdf=build_input.out,
			hdf_output=stats_hdf,
			json_output=stats_json
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
		preemptible: 0
		noAddress: true
	}
}


task QC {
	File fg_minimum_data
	File fg_first_events
	File fg_longit
	String soutput

	command {
		python3 /app/qc.py ${fg_minimum_data} ${fg_first_events} ${fg_longit} ${soutput}
	}

	output {
		File out = "${soutput}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "52 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task densify_first_events {
	File fg_first_events
	File longit_transient  # only here for ordering QC -> densify -> build_input
	String dense_output

	command {
		env LOG_LEVEL=DEBUG python3 /app/densify_first_events.py ${fg_first_events} ${dense_output}
	}

	output {
		File out = "${dense_output}"
		File out_longit_transient = "${longit_transient}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "52 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task build_input {
	File fg_longit
	File fg_minimum_data
	File fg_endpoint_defs
	File fg_samples
	File dense_output
	String hdf_output

	command {
		python3 /app/build_input_hdf.py ${dense_output} ${fg_longit} ${fg_minimum_data} ${fg_endpoint_defs} ${fg_samples} ${hdf_output}
	}

	output {
		File out = "${hdf_output}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "52 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task aggregate_stats {
	File input_hdf
	String hdf_output
	String json_output

	command {
		python3 /app/aggregate_by_endpoint.py ${input_hdf} ${hdf_output}
		python3 /app/stats_to_json.py ${hdf_output} ${json_output}
	}

	output {
		File out = "${json_output}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "26 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}


task filtered_pairs {
	File input_hdf
	File fg_endpoint_defs
	File icd10cm
	File icd10finn
	String filtered_pairs_output

	command {
		python3 /app/surv_endpoints.py ${input_hdf} ${fg_endpoint_defs} ${icd10cm} ${icd10finn} ${filtered_pairs_output}
	}

	output {
		File out = "${filtered_pairs_output}"
	}

	runtime {
		docker: "eu.gcr.io/finngen-refinery-dsgelab/wdl-risteys"
		cpu: "1"
		memory: "26 GB"
		disks: "local-disk 50 SSD"
		zones: "europe-west1-b"
		preemptible: 0
		noAddress: true
	}
}
