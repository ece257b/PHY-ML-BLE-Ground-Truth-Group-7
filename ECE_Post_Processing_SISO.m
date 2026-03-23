%% Load Data
load('.\data.mat')

%% Find BLE Channels
Fs = 100e6;
data = data(:);
x = data(1:5e6);

% PSD
[pxx,f] = pwelch(x, hamming(4096), 2048, 4096, Fs, 'centered');
pxx_db = 10*log10(pxx);
pxx_db = movmean(pxx_db,60);

% Find spectral peaks
[pk,locs] = findpeaks(pxx_db,'MinPeakProminence',5);

freq_candidates = f(locs);

% Measure bandwidth around each peak
bw_limit = 1.5e6; 
valid_freqs = [];

for k = 1:length(locs)

    peak_idx = locs(k);
    peak_val = pxx_db(peak_idx);

    % 3 dB bandwidth
    left = peak_idx;
    while left > 1 && pxx_db(left) > peak_val-3
        left = left-1;
    end

    right = peak_idx;
    while right < length(pxx_db) && pxx_db(right) > peak_val-3
        right = right+1;
    end

    bw = abs(f(right) - f(left));

    if bw <= bw_limit
        valid_freqs(end+1) = f(peak_idx);
    end

end

% Sort frequencies
valid_freqs = sort(valid_freqs);

% Assign BLE channels (lowest to highest)
freq37 = valid_freqs(1);
freq38 = valid_freqs(2);
freq39 = valid_freqs(3);

disp([freq37 freq38 freq39])

%% Isolate BLE Channels

% BLE 38

t = (0:length(data)-1).'/Fs;

ble38 = data .* exp(-1j*2*pi*(freq38)*t);

bw = 2.5e6; % BW = 1.5 MHz

lp = designfilt('lowpassfir', ...
    'FilterOrder',400, ...
    'CutoffFrequency',bw/2, ...
    'SampleRate',Fs);

ble38 = filter(lp, ble38);

% BLE 37

ble37 = data .* exp(-1j*2*pi*(freq37)*t);
ble37 = filter(lp, ble37);

% BLE 39

ble39 = data .* exp(-1j*2*pi*(freq39)*t);
ble39 = filter(lp, ble39);

%% Read PCAP
p = pcapReader('capture1.pcap');
packets = readAll(p);
num_packets = length(packets);

%% Storage
timestamps_us = zeros(num_packets,1);
channels_sniffer = zeros(num_packets,1);
rssi = zeros(num_packets,1);
packet_len = zeros(num_packets,1);
payload_len = zeros(num_packets,1);
access_address = zeros(num_packets,1);

%% Parse Nordic Sniffer Header
for k = 1:num_packets
    bytes = packets(k).RawBytes;
   
    % RSSI
    rssi(k) = typecast(uint8(bytes(11)),'int8');
    
    % Timestamp
    ts_bytes = bytes(14:17);
    timestamps_us(k) = double(typecast(uint8(ts_bytes),'uint32'));  
    
    % Channel
    channels_sniffer(k) = bytes(10);
    
    % Packet and Payload length 
    
    packet_len(k) = uint8(bytes(8));
    payload_len(k) = double(typecast(uint8(bytes(2:3)),'uint16'));

    % Access Address
    access_address(k) = typecast(uint8(bytes(18:21)),'uint32');
end
disp("Timestamps in ms:")
disp(timestamps_us(1:10))

%% Convert timestamps to seconds

timestamps_sec = double(timestamps_us) * 1e-6;
[timestamps_sec, sort_idx] = sort(timestamps_sec);
timestamps_sec = timestamps_sec - timestamps_sec(1);

channels_sniffer = channels_sniffer(sort_idx);
payload_len = payload_len(sort_idx);
packet_len = packet_len(sort_idx);
access_address = access_address(sort_idx);
rssi = rssi(sort_idx);

%% Convert to samples for your SDR capture 
start_samples = round(timestamps_sec * Fs); 
BLE_bytes = payload_len + 10;   % preamble + AA + header + CRC
len_samples = round(BLE_bytes * 8 * Fs / 1e6);


%% Separate channels

idx37 = channels_sniffer == 37;
idx38 = channels_sniffer == 38;
idx39 = channels_sniffer == 39;

starts37 = start_samples(idx37);
starts38 = start_samples(idx38);
starts39 = start_samples(idx39);

len37 = len_samples(idx37);
len38 = len_samples(idx38);
len39 = len_samples(idx39);

disp("Packets per channel:")
disp([length(starts37) length(starts38) length(starts39)])

disp("Packet Starts:")
disp([starts37(1:5) starts38(1:5) starts39(1:5)])

%% Post-Processing 

channels = {ble37, ble38, ble39};
starts = {starts37, starts38, starts39};
lengths = {len37, len38, len39};

results = struct;

for c = 1:3

    sig = channels{c};
    pkt_starts = starts{c};
    pkt_lengths = lengths{c};

    for k = 1:length(pkt_starts)

        s = pkt_starts(k);
        L = pkt_lengths(k);

        if s > 0 && s + L - 1 <= length(sig)

            pkt = sig(s:s+L-1);

            % DC Offset Removal
            pkt = pkt - mean(pkt);

            % Amplitude Normalization
            pkt = pkt ./ sqrt(mean(abs(pkt).^2));

            % CFO Estimation
            pre_len = min(800,length(pkt));
            preamble = pkt(1:pre_len);

            phase_diff = angle(preamble(2:end) .* conj(preamble(1:end-1)));
            CFO_est = Fs/(2*pi) * mean(phase_diff);

            % CFO Correction
            n = (0:length(pkt)-1).';

            pkt_cfo_corrected = pkt .* exp(-1j*2*pi*CFO_est*n/Fs);

            if k <= 10

            figure
            scatter(real(pkt_cfo_corrected), imag(pkt_cfo_corrected),5,'.')
            axis equal
            title(sprintf('Packet Constellation (Channel %d at %d)',c, s/Fs))

            inst_freq = Fs/(2*pi) * diff(unwrap(angle(pkt_cfo_corrected)));

            figure
            plot(inst_freq)
            title(sprintf('Instantaneous Frequency (Channel %d at %d)',c, s/Fs))
            end

            % Phase Tracking
            phase = unwrap(angle(pkt_cfo_corrected));

            % remove linear phase trend
            poly = polyfit(n, phase, 1);
            phase_tracked = phase - polyval(poly, n);

            % Store Results

            results(c).packet{k} = pkt_cfo_corrected; % Processed packet samples
            results(c).CFO(k) = CFO_est; % carrier frequency offset
            results(c).phase{k} = phase_tracked; %phase after tracking
            
        end
    end
end

%% Convert to time
timestamp_37 = starts37 / Fs;
timestamp_38 = starts38 / Fs;
timestamp_39 = starts39 / Fs;
