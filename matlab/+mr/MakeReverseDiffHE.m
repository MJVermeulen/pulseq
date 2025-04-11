function [GxdiffBegin_reverse,GydiffBegin_reverse,GzdiffBegin_reverse,GxdiffEnd_reverse,GydiffEnd_reverse,GzdiffEnd_reverse,he_array_reverse] = MakeReverseDiffHE(GxdiffBegin,GydiffBegin,GzdiffBegin,GxdiffEnd,GydiffEnd,GzdiffEnd,he_array,rf_he_phase_reverse,rf_he_angle_reverse,system)
    GzdiffEnd_reverse = GzdiffEnd;
    GzdiffEnd_reverse.waveform = flip(GzdiffEnd.waveform);
    GzdiffEnd_reverse.tt = abs(flip(GzdiffEnd.tt) - GzdiffEnd.shape_dur);

    GzdiffEnd_reverse.first = GzdiffEnd.last;
    GzdiffEnd_reverse.last = GzdiffEnd.first;

    %GzdiffEnd_reverse.delay = GzdiffEnd.delay;

    GzdiffBegin_reverse = GzdiffBegin;
    GzdiffBegin_reverse.waveform = flip(GzdiffBegin.waveform);
    GzdiffBegin_reverse.tt = abs(flip(GzdiffBegin.tt) - GzdiffBegin.shape_dur);


    GzdiffBegin_reverse.first = GzdiffBegin.last;
    GzdiffBegin_reverse.last = GzdiffBegin.first;




    GxdiffEnd_reverse = GxdiffEnd;
    GxdiffEnd_reverse.waveform = flip(GxdiffEnd.waveform);
    GxdiffEnd_reverse.tt = abs(flip(GxdiffEnd.tt) - GxdiffEnd.shape_dur);

    GxdiffEnd_reverse.first = GxdiffEnd.last;
    GxdiffEnd_reverse.last = GxdiffEnd.first;

    %GxdiffEnd_reverse.delay = 0;

    GxdiffBegin_reverse = GxdiffBegin;
    GxdiffBegin_reverse.waveform = flip(GxdiffBegin.waveform);
    GxdiffBegin_reverse.tt = abs(flip(GxdiffBegin.tt) - GxdiffBegin.shape_dur);

    GxdiffBegin_reverse.first = GxdiffBegin.last;
    GxdiffBegin_reverse.last = GxdiffBegin.first;




    GydiffEnd_reverse = GydiffEnd;
    GydiffEnd_reverse.waveform = flip(GydiffEnd.waveform);
    GydiffEnd_reverse.tt = abs(flip(GydiffEnd.tt) - GydiffEnd.shape_dur);

    GydiffEnd_reverse.first = GydiffEnd.last;
    GydiffEnd_reverse.last = GydiffEnd.first;

    GydiffBegin_reverse = GydiffBegin;
    GydiffBegin_reverse.waveform = flip(GydiffBegin.waveform);
    GydiffBegin_reverse.tt = abs(flip(GydiffBegin.tt) - GydiffBegin.shape_dur);

    GydiffBegin_reverse.first = GydiffBegin.last;
    GydiffBegin_reverse.last = GydiffBegin.first;

    he_array_reverse = he_array;
    

    rf_he_duration = he_array(1).rf.shape_dur;
    %[rf_he_ind_reverse] = mr.makeBlockPulse(rf_he_angle_reverse, 'Duration' , rf_he_duration,'timeBwProduct', 4 , 'system', system, 'PhaseOffset', rf_he_phase_reverse);  
    numberOfPulses = ceil(size(he_array,2)/2);
    for i = 1:(2*numberOfPulses-1)

        if mod(i, 2) ~= 0
         he_array_reverse(i).rf.signal = flip(he_array(i).rf.signal);
         %he_array_reverse(i).rf.signal = rf_he_ind_reverse.signal;
         he_array_reverse(i).rf.t = abs(flip(he_array(i).rf.t) - he_array(i).rf.shape_dur);
         he_array_reverse(i).rf.phaseOffset = rf_he_phase_reverse;
        end


    he_array_reverse(i).Gxdiff.waveform = flip(he_array(i).Gxdiff.waveform);
    he_array_reverse(i).Gxdiff.tt = abs(flip(he_array(i).Gxdiff.tt - he_array(i).Gxdiff.shape_dur));

    he_array_reverse(i).Gxdiff.first = he_array(i).Gxdiff.last;
    he_array_reverse(i).Gxdiff.last = he_array(i).Gxdiff.first;

    he_array_reverse(i).Gydiff.waveform = flip(he_array(i).Gydiff.waveform);
    he_array_reverse(i).Gydiff.tt = abs(flip(he_array(i).Gydiff.tt - he_array(i).Gydiff.shape_dur));

    he_array_reverse(i).Gydiff.first = he_array(i).Gydiff.last;
    he_array_reverse(i).Gydiff.last = he_array(i).Gydiff.first;

    he_array_reverse(i).Gzdiff.waveform = flip(he_array(i).Gzdiff.waveform);
    %disp(he_array_reverse(i).Gzdiff.waveform)
    he_array_reverse(i).Gzdiff.tt = abs(flip(he_array(i).Gzdiff.tt - he_array(i).Gzdiff.shape_dur));

    he_array_reverse(i).Gzdiff.first = he_array(i).Gzdiff.last;
    he_array_reverse(i).Gzdiff.last = he_array(i).Gzdiff.first;
        
   
    end
        
   
end