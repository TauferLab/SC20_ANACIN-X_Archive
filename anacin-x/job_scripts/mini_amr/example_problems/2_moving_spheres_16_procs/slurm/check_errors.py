#!/usr/bin/env python3

#SBATCH -o check_errors-&j.out
#SBATCH -e check_errors-&j.err

import argparse 
import glob
import os

if __name__ == "__main__":
    desc = ""
    parser = argparse.ArgumentParser(description=desc)
    parser.add_argument("job_dir", 
                        help="The directory containing job stderr output to check")
    args = parser.parse_args()
    job_stderrs = glob.glob(args.job_dir + "/*.err")
    for path in job_stderrs:
        with open(path, "r") as logfile:
            lines = logfile.readlines()
            if len(lines) != 0:
                print("Job {} failed".format(os.path.splitext(os.path.basename(path))[0]))


