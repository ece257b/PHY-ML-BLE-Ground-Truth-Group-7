Fs = 100e6;
Fc = 2.45e9;
cfgLLAdv = bleLLAdvertisingChannelPDUConfig(PDUType="Advertising indication", ...
    AdvertisingData="0123456789ABCDEF", ...
    AdvertiserAddress="1234567890AB");
messageBits = bleLLAdvertisingChannelPDU(cfgLLAdv);
channelIndex = 37;
accessAddressLen = 32;
accessAddressHex = "8E89BED6";
accessAddressBin = int2bit(hex2dec(accessAddressHex),accessAddressLen,false);

sps = Fs/(1e6);

txWaveform = bleWaveformGenerator(messageBits, ...
    Mode="LE1M", ...
    SamplesPerSymbol=sps, ...
    ChannelIndex=channelIndex, ...
    AccessAddress=accessAddressBin);

%% Concatenate with recorded IQ samples

load('data.mat');
n = (0:numel(txWaveform)-1).';
fOffset = -48e6;                 % channel 37 relative to 2.45 GHz center
pkt37 = txWaveform .* exp(1j*2*pi*fOffset/Fs*n);

S = load('data.mat','data');   
data = S.data;
save('data_v73.mat','data','-v7.3');
clear S data

src = matfile("data_v73.mat");
dst = matfile("data_sync.mat","Writable",true);

pkt = single(pkt37(:)).';              % generated BLE marker, complex column
alpha = single(0.3);               % marker scaling
Tmark = 0.01;                       % marker spacing in seconds
L = numel(pkt);

N = size(src,"data",2);          % number of recorded samples
starts = 1 : round(Tmark*Fs) : (N-L+1);   % example first start at sample 1e6

% Preallocate complex output without loading everything
chunk = 1e6;
dst.iq_out(1,N) = complex(single(0), single(0));

for c0 = 1:chunk:N
    c1 = min(c0 + chunk - 1, N);

    % Read one row slice
    y = single(src.data(1, c0:c1));

    % Add any markers overlapping this chunk
    idx = find(starts <= c1 & (starts + L - 1) >= c0);

    for ii = idx
        s = starts(ii);
        e = s + L - 1;

        ov0 = max(c0, s);
        ov1 = min(c1, e);

        yIdx = (ov0 - c0 + 1):(ov1 - c0 + 1);
        pIdx = (ov0 - s + 1):(ov1 - s + 1);

        y(yIdx) = y(yIdx) + alpha * pkt(pIdx);
    end

    % Write row slice back out
    dst.iq_out(1, c0:c1) = y;
end
%% Write back to sigmf

m = matfile("data_sync.mat");
N = size(m, "iq_out", 2);

% ==== Write SigMF dataset (.sigmf-data) ====
fid = fopen('output.sigmf-data', 'w');


for c0 = 1:chunk:N
    c1 = min(c0 + chunk - 1, N);

    % Read one chunk from the 1xN row vector
    iq_chunk = m.('iq_out')(1, c0:c1);

    % Convert to single precision to match cf32_le
    iq_chunk = single(iq_chunk);

    % Interleave I and Q: I0 Q0 I1 Q1 ...
    tmp = zeros(2*numel(iq_chunk), 1, 'single');
    tmp(1:2:end) = real(iq_chunk);
    tmp(2:2:end) = imag(iq_chunk);

    fwrite(fid, tmp, 'single');
end

fclose(fid);

% ==== Write SigMF metadata (.sigmf-meta) ====
meta = sprintf([ ...
'{\n' ...
'  "global": {\n' ...
'    "core:version": "1.2.6",\n' ...
'    "core:datatype": "cf32_le",\n' ...
'    "core:sample_rate": %.17g\n' ...
'  },\n' ...
'  "captures": [\n' ...
'    {\n' ...
'      "core:sample_start": 0,\n' ...
'      "core:frequency": %.17g\n' ...
'    }\n' ...
'  ],\n' ...
'  "annotations": []\n' ...
'}\n'], Fs, Fc);
fid = fopen('output.sigmf-meta', 'w');
fwrite(fid, meta, 'char');
fclose(fid);
