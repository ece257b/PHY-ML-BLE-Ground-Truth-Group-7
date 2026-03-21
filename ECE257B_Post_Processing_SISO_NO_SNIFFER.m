%% Find BLE Channels
load('C:\Users\cryba\MATLAB Drive\data.mat')

%% Measure bandwidth around each peak
Fs = 100e6;

data = data(:);
x = data(1:5e6);

%% PSD
[pxx,f] = pwelch(x, hamming(4096), 2048, 4096, Fs, 'centered');
pxx_db = 10*log10(pxx);
pxx_db = movmean(pxx_db,60);

% figure
% plot(f/1e6,pxx_db)
% xlabel('Frequency (MHz)')
% ylabel('PSD (dB)')
% title('PSD with smoothing')

% figure
% spectrogram(x,1024,768,1024,Fs,'centered')
% colorbar
% title('Full Spectrum')

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

% figure(5)
% spectrogram(ble38(1:5e6),1024,768,1024,Fs,'centered')
% colorbar
% title('BLE 38')

% figure(6)
% pwelch(ble38(1:5e6), hamming(4096), 2048, 4096, Fs, 'centered')

% BLE 37

ble37 = data .* exp(-1j*2*pi*(freq37)*t);
ble37 = filter(lp, ble37);

% figure(7)
% spectrogram(ble37(1:5e6),1024,768,1024,Fs,'centered')
% colorbar
% title('BLE 37')

% figure(8)
% pwelch(ble37(1:5e6), hamming(4096), 2048, 4096, Fs, 'centered')

% BLE 39

ble39 = data .* exp(-1j*2*pi*(freq39)*t);
ble39 = filter(lp, ble39);

% figure(9)
% spectrogram(ble39(1:5e6),1024,768,1024,Fs,'centered')
% colorbar
% title('BLE 39')

% figure(10)
% pwelch(ble39(1:5e6), hamming(4096), 2048, 4096, Fs, 'centered')

%% Packet detection

% 38 (-24 MHz)
scale38 = 15^3;
power38 = abs(ble38).^2;
energy38 = movmean(power38,200);    % smooth small fluctuations

% Use a threshold relative to max instead of median
threshold38 = scale38*median(energy38);  % 30% of peak energy, adjust if needed

% Detect regions above threshold
packets38 = energy38 > threshold38;

% Get rising edges (packet starts)
starts38 = find(diff(packets38) == 1);

% Remove starts too close together (BLE packets are short, ~100us)
min_spacing = round(Fs * 100e-6); 
starts38 = starts38([true; diff(starts38) > min_spacing]);

% 37 (-48 MHz)
scale37 = 20^3;
power37 = abs(ble37).^2;
energy37 = movmean(power37,200);    % smooth small fluctuations

% Use a threshold relative to max instead of median
threshold37 = scale37*median(energy37);  % 30% of peak energy, adjust if needed

% Detect regions above threshold
packets37 = energy37 > threshold37;

% Get rising edges (packet starts)
starts37 = find(diff(packets37) == 1);

% Remove starts too close together (BLE packets are short, ~100us)
starts37 = starts37([true; diff(starts37) > min_spacing]);

% 39 (30 MHz)
scale39 = 42.5^3;
power39 = abs(ble39).^2;
energy39 = movmean(power39,200);    % smooth small fluctuations

% Use a threshold relative to max instead of median
threshold39 = scale39*median(energy39);  % 30% of peak energy, adjust if needed

% Detect regions above threshold
packets39 = energy39 > threshold39;

% Get rising edges (packet starts)
starts39 = find(diff(packets39) == 1);

% Remove starts too close together (BLE packets are short, ~100us)
starts39 = starts39([true; diff(starts39) > min_spacing]);

%% Plot Packet Detection Peaks
% figure(11)
% plot(energy38)
% hold on
% yline(threshold38,'r--')
% 
% title('Packet Detection for BLE 38')
% xlabel('Sample')
% ylabel('Energy')
% 
% figure(12)
% plot(energy37)
% hold on
% yline(threshold37,'r--')
% 
% title('Packet Detection for BLE 37')
% xlabel('Sample')
% ylabel('Energy')
% 
% figure(13)
% plot(energy39)
% hold on
% yline(threshold39,'r--')
% 
% 
% title('Packet Detection for BLE 39')
% xlabel('Sample')
% ylabel('Energy')

%% Plots to check Packet Detection

xlen = 5e6; % samples you are plotting in the spectrogram
win = 1024;
noverlap = 768;
nfft = 1024;

% % BLE 38
% figure
% [S38,F38,T38] = spectrogram(ble38(1:xlen), win, noverlap, nfft, Fs, 'centered');
% surf(T38,F38,20*log10(abs(S38)),'EdgeColor','none');
% axis tight; view(0,90);
% xlabel('Time [s]'); ylabel('Frequency [Hz]'); colorbar;
% title('BLE 38 Packet Detection on Spectrogram'); hold on
% 
% % Convert start indices to time (s)
% time_starts38 = starts38(starts38 <= xlen)/ Fs;
% 
% % Overlay vertical lines at packet starts
% for k = 1:length(time_starts38)
%     plot([time_starts38(k) time_starts38(k)], [min(F38) max(F38)], 'r', 'LineWidth', 1.5);
% end
% 
% % BLE 37
% figure
% [S37,F37,T37] = spectrogram(ble37(1:xlen), win, noverlap, nfft, Fs, 'centered');
% surf(T37,F37,20*log10(abs(S37)),'EdgeColor','none');
% axis tight; view(0,90);
% xlabel('Time [s]'); ylabel('Frequency [Hz]'); colorbar;
% title('BLE 37 Packet Detection on Spectrogram'); hold on
% 
% time_starts37 = starts37(starts37 <= xlen) / Fs;
% for k = 1:length(time_starts37)
%     plot([time_starts37(k) time_starts37(k)], [min(F37) max(F37)], 'r', 'LineWidth', 1.5);
% end
% 
% % BLE 39
% figure
% [S39,F39,T39] = spectrogram(ble39(1:xlen), win, noverlap, nfft, Fs, 'centered');
% surf(T39,F39,20*log10(abs(S39)),'EdgeColor','none');
% axis tight; view(0,90);
% xlabel('Time [s]'); ylabel('Frequency [Hz]'); colorbar;
% title('BLE 39 Packet Detection on Spectrogram'); hold on
% 
% time_starts39 = starts39(starts39 <= xlen) / Fs;
% for k = 1:length(time_starts39)
%     plot([time_starts39(k) time_starts39(k)], [min(F39) max(F39)], 'r', 'LineWidth', 1.5);
% end
% 
% disp("Packets per channel:")
% disp([length(starts37) length(starts38) length(starts39)])
% 
% disp('Packet Starts:')
% disp([starts37(1:5) starts38(1:5) starts39(1:5)])

%% Per packet processing

channels = {ble37, ble38, ble39};
starts   = {starts37, starts38, starts39};

packet_len = round(330e-6 * Fs); 

results = struct;

for c = 1:3

    sig = channels{c};
    pkt_starts = starts{c};

    for k = 1:length(pkt_starts)

        s = pkt_starts(k);

        if s + packet_len <= length(sig)

            pkt = sig(s:s+packet_len-1);

            % DC Offset Removal
            pkt = pkt - mean(pkt);

            % Amplitude Normalization
            pkt = pkt ./ sqrt(mean(abs(pkt).^2));

            % CFO Estimation
            preamble = pkt(1:800);

            phase_diff = angle(preamble(2:end) .* conj(preamble(1:end-1)));
            
            CFO_est = Fs/(2*pi) * mean(phase_diff);

            % CFO Correction
            n = (0:length(pkt)-1).';

            pkt_cfo_corrected = pkt .* exp(-1j*2*pi*CFO_est*n/Fs);

            if k <= 3

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
            p = polyfit(n, phase, 1);
            phase_tracked = phase - polyval(p, n);

            % Store Results

            results(c).packet{k} = pkt_cfo_corrected; % Processed packet samples
            results(c).CFO(k) = CFO_est; % carrier frequency offset
            results(c).phase{k} = phase_tracked; %phase after tracking
            
        end
    end
end

%% 

% figure
% histogram(results(1).CFO,50)
% title('CFO Distribution Channel 37')
% xlabel('Hz')
% 
% figure
% histogram(results(2).CFO,50)
% title('CFO Distribution Channel 38')
% xlabel('Hz')
% 
% figure
% histogram(results(3).CFO,50)
% title('CFO Distribution Channel 39')
% xlabel('Hz')

%% 
% pkt = results(2).packet{1};
% 
% figure
% plot(real(pkt))
% hold on
% plot(imag(pkt))
% title('Packet IQ')
% 
% figure
% plot(results(2).phase{1})
% title('Packet phase')

%% Convert to Time
timestamp_37 = starts37 / Fs;
timestamp_38 = starts38 / Fs;
timestamp_39 = starts39 / Fs;
