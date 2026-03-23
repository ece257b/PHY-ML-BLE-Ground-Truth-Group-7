# Cross Evaluation Report

**Project Title:** _PHY-ML BLE Ground Truth Generation_  
**Authors:** _Alexis Emmanuelle Pascual, Yusuf Amanullah, Andrew Fu_

## 1. Documentation

Is the artifact/code sufficiently documented? Rate from 0% to 100%, where 0% means **"documentation is completely insufficient"** and 100% means **"documentation is absolutely sufficient"**.

If you need to assess both a dataset and tools, please take the average and comment below. In assessing tools, please consider whether they are easy or difficult to install, set up, and run. In assessing datasets, please consider whether the metadata is sufficient.

**Choices:**

- [ ] 0%
- [ ] 20%
- [ ] 40%
- [ ] 60%
- [X] 80%
- [ ] 100%

**Documentation Comment:**  
The README is not enough to identify the main scripts, the bundled capture files, and the missing external prerequisites. It is still not fully self-contained because some workflows depend on MATLAB capabilities (`pcapReader`, BLE waveform generation) and hardware assumptions that are only obvious after trying to run the code.

## 2. Completeness

Do the submitted artifacts/code include all of the key components described in the report? Rate from 0% to 100%, where 0% means **"does not include any key components"** and 100% means **"includes all key components"**.

**Choices:**

- [ ] 0%
- [ ] 20%
- [ ] 40%
- [X] 60%
- [ ] 80%
- [ ] 100%

**Completeness Comment:**  
The repository includes the main MATLAB scripts, a large bundled capture, SigMF metadata, and helper scripts. The sniffer-side PCAP files needed for the time-aligned SISO and SIMO workflows are not present, so the checkout is missing part of the artifact needed for full reproduction.

## 3. Exercisability

Do the submitted artifacts/code include the scripts and data needed to run the experiments described in the paper, and can the software be successfully executed? Rate from 0% to 100%, where 0% means **"the scripts/software cannot be successfully executed and/or no data is included"** and 100% means **"the artifact includes all necessary scripts/software and data, and scripts/software (if present) can be successfully executed"**.

**Choices:**

- [ ] 0%
- [ ] 20%
- [ ] 40%
- [X] 60%
- [ ] 80%
- [ ] 100%

**Exercisability Comment:**  
After patching the repo-local paths, I was able to execute `ECE257B_Post_Processing_SISO_NO_SNIFFER.m` successfully on the bundled capture, and the MATLAB environment now provides `pcapReader` plus the relevant signal-processing functions. The sniffer-dependent scripts still cannot run from this checkout because the required `capture1.pcap` and `capture_sync.pcap` files are not in the repository.

## 4. Results Attainable

Does the artifact/code make it possible, with reasonable effort, to obtain the key results from the artifact/code? Rate from 0% to 100%, where 0% means **"no results can be obtained"** and 100% means **"all results can be obtained"**.

**Choices:**

- [ ] 0%
- [ ] 20%
- [ ] 40%
- [X] 60%
- [ ] 80%
- [ ] 100%

**Results Attainable Comment:**  
The no-sniffer SISO path is attainable from the current checkout. The time-aligned SISO and SIMO results are still only partially reproducible because they depend on missing sniffer PCAP artifacts, but the earlier toolbox-side blocker has been removed.

## 5. Results Completeness

How many key results of the paper/report is the provided code meant to support? Rate from 0% to 100%, where 0% means **"the artifact is meant to support no key results"** and 100% means **"the artifact is meant to support all key results"**.

**Choices:**

- [ ] 0%
- [ ] 20%
- [ ] 40%
- [ ] 60%
- [X] 80%
- [ ] 100%

**Results Completeness Comment:**  
The codebase appears intended to support the main SISO, time-aligned SISO, and SIMO analyses shown in the README. The main limitation is not intent but packaging: some required artifacts and dependencies are outside the repository.

## Signatures

- Reviewer _Ned Bitar_, Signature: Ned Bitar
- Reviewer _Diya Arun_, Signature: Diya Arun
- Reviewer _Pranav Mehta_, Signature: Pranav Mehta