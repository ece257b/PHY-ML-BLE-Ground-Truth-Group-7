# PHY-ML BLE Ground Truth Generation Setup Guide

## Quick Start

1. **Download the following .mat and sigmf-meta files.**
   - SISO: https://drive.google.com/file/d/1KyPsnNOpxRH5J6BxJk8TaDZziSLUaW4R/view?usp=sharing
   - MIMO: https://drive.google.com/file/d/1Buqu8cthTfpJxYtxIyuBDFtkwrwAbxl7/view?usp=sharing
   - sigmf-meta Files
     - https://drive.google.com/file/d/1kXfIQsRrEWQO6mH43YSe4zSW4E3jSuHO/view?usp=sharing
     - https://drive.google.com/file/d/1v7sKhW5pcQMxYYbn6Gc8blcyt8-yQ2ts/view?usp=sharing

2. **Change file paths in all .m files to destination files.**

3. **Rename output.mat to data.mat.**

## Results

### SISO w/ Sniffer

- Run ``ECE_Post_Processing_SISO.m`` for results without time alignment.
- Run ``ECE_257B_Post_Processing_SISO_TA.m`` for results with time alignment.

| w/o TA | w/ TA |
| :---: | :---: |
| <img src="./images/SISO_NO_TA.png" height="300"> | <img src="./images/SISO_TA.png" height="300"> |

### SISO w/o Sniffer

- Run ``ECE_Post_Processing_SISO_NO_SNIFFER.m`` for power-based packet detection results.

<img src="./images/SISO_Power.png" width="500">
<img src="./images/SISO_Power_Packet.png" width="500">

## Helper Scripts

- ``generate_sync_packets.m``: Generates a synthetic BLE packet and inserts it at fixed time intervals of recorded IQ samples. Used for time alignment.
- ``bin2mat.m``: Converts sigmf-data (binary) file to .mat file.
- ``tx.py``: Transmits pre-recorded IQ data from USRP.
