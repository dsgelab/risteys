extern crate csv;

use std::collections::HashMap;
use std::error::Error;
use std::io;


const COL_FGID: usize = 0;  // assume FINNGENID is the first column


fn main() -> Result<(), Box<dyn Error>> {
    // 1. Init
    let mut rdr = csv::Reader::from_reader(io::stdin());
    let mut record = csv::ByteRecord::new();
    let mut wtr = csv::Writer::from_writer(io::stdout());
    wtr.write_record(&["FINNGENID", "ENDPOINT", "AGE", "YEAR", "NEVT"])
        .expect("Failed to write header line");


    // 2. Get headers
    let mut cols = HashMap::new();
    let headers = rdr.headers().expect("Failed to get headers").to_owned();
    for (idx, field) in headers.iter().enumerate() {
        cols.insert(field.to_string(), idx);
    }

    // 3. Get endpoints
    let mut endpoints: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut age = String::new();
    let mut year = String::new();
    let mut nevt = String::new();
    let iter_endpoints = headers.iter().filter(
        |&field| {
            current = field.to_string();
            age = format!("{}_AGE", current);
            year = format!("{}_YEAR", current);
            nevt = format!("{}_NEVT", current);
            cols.contains_key(&age) && cols.contains_key(&year) && cols.contains_key(&nevt)
        }
    );
    for endp in iter_endpoints {
        endpoints.push(endp.to_string());
    }

    // 4. Iter records
    let mut count = 0;
    let mut out_line = csv::ByteRecord::new();
    while rdr.read_byte_record(&mut record).expect("Can't get record") {
        count += 1;

        // Check which endpoints the indiv has
        for endp in &endpoints {
            let col = cols.get(endp).expect("col not found in header");
            if &record[*col] == b"1" {
                // Get the event info
                age = format!("{}_AGE", endp);
                year = format!("{}_YEAR", endp);
                nevt = format!("{}_NEVT", endp);
                let col_age = cols.get(&age).unwrap();
                let col_year = cols.get(&year).unwrap();
                let col_nevt = cols.get(&nevt).unwrap();
                let val_fgid = &record[COL_FGID];
                let val_age = &record[*col_age];
                let val_year = &record[*col_year];
                let val_nevt = &record[*col_nevt];

                // Build and write the output line
                out_line.clear();
                out_line.push_field(val_fgid);
                out_line.push_field(endp.as_bytes());
                out_line.push_field(val_age);
                out_line.push_field(val_year);
                out_line.push_field(val_nevt);
                wtr.write_byte_record(&out_line).unwrap();
            }
        }
    }

    // 5. Clean-up
    wtr.flush().expect("Writer flush failed");

    eprintln!("Lines processed: {}", count);
    Ok(())
}
