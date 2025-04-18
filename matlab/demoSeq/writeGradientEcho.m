% set system limits
sys = mr.opts('MaxGrad', 22, 'GradUnit', 'mT/m', ...
    'MaxSlew', 120, 'SlewUnit', 'T/m/s', ... 
    'rfRingdownTime', 20e-6, 'rfDeadTime', 100e-6, 'adcDeadTime', 10e-6);

seq=mr.Sequence(sys);           % Create a new sequence object
fov=256e-3; Nx=128; Ny=Nx;      % Define FOV and resolution
alpha=10;                       % flip angle
sliceThickness=3e-3;            % slice
TR=12e-3;                       % repetition time TR
TE=5e-3;                        % echo time TE  
%TE=[7.38 9.84]*1e-3;            % alternatively give a vector here to have multiple TEs (e.g. for field mapping)

% more in-depth parameters
rfSpoilingInc=117;              % RF spoiling increment
roDuration=3.2e-3;              % ADC duration

% Create fat-sat pulse 
% (in Siemens interpreter from January 2019 duration is limited to 8.192 ms, and although product EPI uses 10.24 ms, 8 ms seems to be sufficient)
% B0=2.89; % 1.5 2.89 3.0
% sat_ppm=-3.45;
% sat_freq=sat_ppm*1e-6*B0*lims.gamma;
% rf_fs = mr.makeGaussPulse(110*pi/180,'system',lims,'Duration',8e-3,...
%     'bandwidth',abs(sat_freq),'freqOffset',sat_freq);
% gz_fs = mr.makeTrapezoid('z',sys,'delay',mr.calcDuration(rf_fs),'Area',1/1e-4); % spoil up to 0.1mm

% Create alpha-degree slice selection pulse and gradient
[rf, gz] = mr.makeSincPulse(alpha*pi/180,sys,'Duration',3e-3,...
    'SliceThickness',sliceThickness,'apodization',0.42,'timeBwProduct',4,...
    'use','excitation');

% Define other gradients and ADC events
deltak=1/fov;
gx = mr.makeTrapezoid('x',sys,'FlatArea',Nx*deltak,'FlatTime',roDuration);
adc = mr.makeAdc(Nx,sys,'Duration',gx.flatTime,'Delay',gx.riseTime);
gxPre = mr.makeTrapezoid('x',sys,'Area',-gx.area/2,'Duration',1e-3);
gzReph = mr.makeTrapezoid('z',sys,'Area',-gz.area/2,'Duration',1e-3);
phaseAreas = ((0:Ny-1)-Ny/2)*deltak;
gyPre = mr.makeTrapezoid('y',sys,'Area',max(abs(phaseAreas)),'Duration',mr.calcDuration(gxPre));
peScales=phaseAreas/gyPre.area;
        

% gradient spoiling
gxSpoil=mr.makeTrapezoid('x',sys,'Area',2*Nx*deltak);
gzSpoil=mr.makeTrapezoid('z',sys,'Area',4/sliceThickness);

% Calculate timing
delayTE=ceil((TE - mr.calcDuration(gxPre) - gz.fallTime - gz.flatTime/2 ...
    - mr.calcDuration(gx)/2)/seq.gradRasterTime)*seq.gradRasterTime;
delayTR=ceil((TR - mr.calcDuration(gz) - mr.calcDuration(gxPre) ...
    - mr.calcDuration(gx) - delayTE)/seq.gradRasterTime)*seq.gradRasterTime;
assert(all(delayTE>=0));
assert(all(delayTR>=mr.calcDuration(gxSpoil,gzSpoil)));

rf_phase=0;
rf_inc=0;

% Loop over phase encodes and define sequence blocks
for i=1:Ny
    for c=1:length(TE)
        %seq.addBlock(rf_fs,gz_fs); % fat-sat
        rf.phaseOffset=rf_phase/180*pi;
        adc.phaseOffset=rf_phase/180*pi;
        rf_inc=mod(rf_inc+rfSpoilingInc, 360.0);
        rf_phase=mod(rf_phase+rf_inc, 360.0);
        %
        seq.addBlock(rf,gz);
        seq.addBlock(gxPre,mr.scaleGrad(gyPre,peScales(i)),gzReph);
        seq.addBlock(mr.makeDelay(delayTE(c)));
        seq.addBlock(gx,adc);
        %gyPre.amplitude=-gyPre.amplitude;
        seq.addBlock(mr.makeDelay(delayTR(c)),gxSpoil,mr.scaleGrad(gyPre,-peScales(i)),gzSpoil)
    end
end

%% check whether the timing of the sequence is correct
[ok, error_report]=seq.checkTiming;

if (ok)
    fprintf('Timing check passed successfully\n');
else
    fprintf('Timing check failed! Error listing follows:\n');
    fprintf([error_report{:}]);
    fprintf('\n');
end

%% prepare sequence export
seq.setDefinition('FOV', [fov fov sliceThickness]);
seq.setDefinition('Name', 'gre');

seq.write('gre.seq')       % Write to pulseq file

%seq.install('siemens');

%% plot sequence and k-space diagrams

seq.plot('timeRange', [0 5]*TR);

% k-space trajectory calculation
[ktraj_adc, t_adc, ktraj, t_ktraj, t_excitation, t_refocusing] = seq.calculateKspacePP();

% plot k-spaces
figure; plot(t_ktraj, ktraj'); % plot the entire k-space trajectory
hold; plot(t_adc,ktraj_adc(1,:),'.'); % and sampling points on the kx-axis
figure; plot(ktraj(1,:),ktraj(2,:),'b'); % a 2D plot
axis('equal'); % enforce aspect ratio for the correct trajectory display
hold;plot(ktraj_adc(1,:),ktraj_adc(2,:),'r.'); % plot the sampling points

%% very optional slow step, but useful for testing during development e.g. for the real TE, TR or for staying within slewrate limits  

rep = seq.testReport;
fprintf([rep{:}]);

