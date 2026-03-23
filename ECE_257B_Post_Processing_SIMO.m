%% Load Data
load('.\ism24gfulls.ota.rx.r001.mat') % Change location

fid = fopen('.\ism24gfulls1.ota.rx.r001.sigmf-meta'); % Change location
raw = fread(fid, inf);
str = char(raw');
fclose(fid);

meta1 = jsondecode(str);

fid = fopen('.\ism24gfulls2.ota.rx.r001.sigmf-meta'); % Change location
raw = fread(fid, inf);
str = char(raw');
fclose(fid);

meta2 = jsondecode(str);

Fs = 100e6;

% Split antennas
data1 = data(:,1);
data2 = data(:,2);

%% Extract timestamps and sample indices

num1 = length(meta1.captures);
num2 = length(meta2.captures);

t1 = zeros(num1,1);
s1 = zeros(num1,1);

t2 = zeros(num2,1);
s2 = zeros(num2,1);

for k = 1:num1
    t1(k) = posixtime(datetime(meta1.captures(k).('core_datetime'), ...
        'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSSSSSSSSSSSSSSS''Z'''));
    s1(k) = meta1.captures(k).('core_sample_start');
end

for k = 1:num2
    t2(k) = posixtime(datetime(meta2.captures(k).('core_datetime'), ...
        'InputFormat','yyyy-MM-dd''T''HH:mm:ss.SSSSSSSSSSSSSSSSS''Z'''));
    s2(k) = meta2.captures(k).('core_sample_start');
end

%% Compute absolute start time of each stream

t1_0 = t1(1) - s1(1)/Fs;
t2_0 = t2(1) - s2(1)/Fs;

delta_t = t2_0 - t1_0;
delta_n = round(delta_t * Fs);

fprintf("Antenna offset (samples): %d\n", delta_n);

%% Align signals using padding
if delta_n > 0
    % Antenna 2 starts later → pad the beginning of data2
    data2 = [zeros(delta_n,1); data2];
elseif delta_n < 0
    % Antenna 1 starts later → pad the beginning of data1
    data1 = [zeros(-delta_n,1); data1];
end

% Make both signals the same length by padding the shorter one at the end
N = max(length(data1), length(data2));
data1(end+1:N) = 0;
data2(end+1:N) = 0;

fprintf("Aligned antenna length: %d samples\n", N);


%% Find BLE Channels (Advertisement only)
freq37 = -48e6;
freq38 = -24e6;
freq39 = 30e6;

disp([freq37, freq38, freq39]);

%% Channel Isolation (BOTH antennas)
t = (0:length(data1)-1).' / Fs;

bw = 2.5e6;
lp = designfilt('lowpassfir', ...
    'FilterOrder',400, ...
    'CutoffFrequency',bw/2, ...
    'SampleRate',Fs);

% Antenna 1
ble37_1 = filter(lp, data1 .* exp(-1j*2*pi*freq37*t));
ble38_1 = filter(lp, data1 .* exp(-1j*2*pi*freq38*t));
ble39_1 = filter(lp, data1 .* exp(-1j*2*pi*freq39*t));

% Antenna 2
ble37_2 = filter(lp, data2 .* exp(-1j*2*pi*freq37*t));
ble38_2 = filter(lp, data2 .* exp(-1j*2*pi*freq38*t));
ble39_2 = filter(lp, data2 .* exp(-1j*2*pi*freq39*t));


%% Read PCAP
p = pcapReader('.\capture_sync.pcap'); % incorrect data file 
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

%% Convert timestamps to seconds
timestamps_sec = timestamps_us * 1e-6;
[timestamps_sec, sort_idx] = sort(timestamps_sec);
timestamps_sec = timestamps_sec - timestamps_sec(1);

channels_sniffer = channels_sniffer(sort_idx);
payload_len = payload_len(sort_idx);
packet_len = packet_len(sort_idx);
access_address = access_address(sort_idx);
rssi = rssi(sort_idx);

%% Time synchronization
% Parameters
SYNC_LEN = 40; % Fixed length of sync packet.
SYNC_SRC_ADR = '1234567890AB'; % Advertising address of sync packet.
SYNC_INT = 0.01; % Time interval between sync packets in milliseconds.

% Clock Drift/Offset Estimation
candSyncIdx = find([packets.PacketLength] == SYNC_LEN); % candidate sync indices
candPktData = [packets(candSyncIdx).Packet]; % candidate packet data
syncIdx = candSyncIdx(all(candPktData(24 : 29, :) == hex2dec(string(flip(reshape(SYNC_SRC_ADR, 2, 6)', 1))))); % sync index
numSyncs = length(syncIdx); % number of syncs
syncTS = timestamps_sec(syncIdx); % sync timestamps
p2 = polyfit([0; cumsum(round(diff(syncTS) / SYNC_INT))], syncTS, 1);
clock_drift = p2(1) - SYNC_INT;
clock_offset = p2(2);

% Printing
disp("Clock drift (per second) and offset:")
fprintf("%d %d\n\n", clock_drift, clock_offset);

% Apply Correction
temp = diff(timestamps_sec(syncIdx));
temp = repelem([0; cumsum(temp - round(temp / SYNC_INT) * SYNC_INT)], [diff(syncIdx) 1]);
timestamps_sec_corrected = timestamps_sec - temp;

% Debugging - timestamps of original signal vs. timestamps of signal with time sync
% disp([timestamps_sec(syncIdx) timestamps_sec_corrected(syncIdx)])


%% Convert to samples
start_samples = round(timestamps_sec_corrected * Fs);
BLE_bytes = payload_len + 10;
len_samples = round(BLE_bytes * 8 * Fs / 1e6);

%% Separate channels
idx37 = channels_sniffer == 37;
idx38 = channels_sniffer == 38;
idx39 = channels_sniffer == 39;

starts = {start_samples(idx37), start_samples(idx38), start_samples(idx39)};
lengths = {len_samples(idx37), len_samples(idx38), len_samples(idx39)};

channels_ant1 = {ble37_1, ble38_1, ble39_1};
channels_ant2 = {ble37_2, ble38_2, ble39_2};

%% Post-Processing (SIMO with alignment)

results = struct;

for c = 1:3

    sig1 = channels_ant1{c};
    sig2 = channels_ant2{c};

    pkt_starts = starts{c};
    pkt_lengths = lengths{c};

    for k = 1:length(pkt_starts)

        s = pkt_starts(k);
        L = pkt_lengths(k);

        % Bounds check
        if s <= 0 || (s+L-1) > length(sig1)
            continue
        end

        pkt1 = sig1(s:s+L-1);
        pkt2 = sig2(s:s+L-1);

        % SNR estimation
        E1 = mean(abs(pkt1).^2);
        E2 = mean(abs(pkt2).^2);

        noise_len = min(200, L);
        N1 = var(pkt1(1:noise_len));
        N2 = var(pkt2(1:noise_len));

        SNR1 = E1 / N1;
        SNR2 = E2 / N2;

        % Antenna Selection
        if SNR1 > SNR2
            pkt = pkt1;
            best_ant = 1;
        else
            pkt = pkt2;
            best_ant = 2;
        end

        % DC Offset Removal
        pkt = pkt - mean(pkt);

        % Normalization
        pkt = pkt ./ sqrt(mean(abs(pkt).^2));

        % CFO Estimation
        pre_len = min(800, length(pkt));
        preamble = pkt(1:pre_len);

        phase_diff = angle(preamble(2:end).*conj(preamble(1:end-1)));
        CFO_est = Fs/(2*pi)*mean(phase_diff);

        % CFO Correction
        n = (0:length(pkt)-1).';
        pkt = pkt .* exp(-1j*2*pi*CFO_est*n/Fs);

        % Debug Plots
        if k <= 3
            figure
            scatter(real(pkt), imag(pkt), 5, '.')
            axis equal
            title(sprintf('Ch%d Packet %d (Ant %d)', c, k, best_ant))

            inst_freq = Fs/(2*pi) * diff(unwrap(angle(pkt)));

            figure
            plot(inst_freq)
            title(sprintf('Instantaneous Frequency (Channel %d at %d)',c, s/Fs))
            
        end

        % Phase Tracking
        phase = unwrap(angle(pkt));
        p = polyfit(n, phase, 1);
        phase_tracked = phase - polyval(p, n);

        % Store
        results(c).packet{k} = pkt;
        results(c).CFO(k) = CFO_est;
        results(c).phase{k} = phase_tracked;
        results(c).best_ant(k) = best_ant;
        results(c).SNR(k,:) = [SNR1 SNR2];

    end
end

timestamp_37 = starts37 / Fs;
timestamp_38 = starts38 / Fs;
timestamp_39 = starts39 / Fs;
