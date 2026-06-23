function [Xfer21,FreqV,P] = xfunc(x,y,fs,m,noverlap)

% Units: x and y must use compatible units; Xfer21 has units y/x,
% FreqV and fs are Hz, Pxx/Pyy are squared input/output units per Hz,
% and Pxy is input*output units per Hz. m and noverlap are sample counts.

%  [XFER21,FREQV,P] = XFUNC(X,Y,FS,M,NOVERLAP) will estimate the 
%	complex transfer function given time histories of the 
%	input, X, and the output, Y. Given the complex response, 
%	the magnitude and phase can be determined by using the 
%	ABS and ANGLE functions. FS is the sampling frequency (Hz) 
%	at which the data was taken. The X and Y sequences of 
%	N points are divided into NS sections of M points each 
%	(M must be a power of two). Using an M-point FFT, 
%	successive sections are Hanning windowed, FFT'd and 
%	averaged.	** SOME PARTS FROM SPECTRUM FUNCTION
%
%	XFUNC(X,Y,FS) 	--> NO AVERAGING
%	XFUNC(X,Y,FS,M)	--> AVERAGING BUT NO OVERLAP
%	NO OUTPUT ARGUMENTS WILL CREATE A BODE PLOT
%
% 	The output P is the matrix of power spectrums in the order
%	P = [Pxx,Pyy,Pxy]. 
%
%	NOTES: 	Xfer data may be written to a specified file.
%		Variables were chosen to immitate certain IP names.
%		Depending on the anti-aliasing filter used a certain 
%			percentage of the data will include aliased 
%			data (IP is 78% correct).

% COMMENTS
% nargin = 3 --> no overlap, no averaging
% nargin = 4 --> no overlap, averaging data
% nargin = 5 --> some overlap, and averaging data
% set color variable to easily change plot color
% may also write data to a file

color	= 'b';

%% Parse optional averaging inputs
if (nargin == 3), m = length(y); noverlap = 0; end
if (nargin == 4)
	if (length(y) == 1)
		noverlap = m;
		m = length(y);
	else
		noverlap = 0;
	end
end
%keyboard
%% Prepare column vectors and window constants
x 	= x(:);		% Make sure x and y are column vectors
y 	= y(:);

% DEFINE CONSTANTS
n 	= max(size(x));	% Number of data points in entire time history
ns 	= fix((n-noverlap)/(m-noverlap));	% Number of samples (frames)
						% (k = fix(n/m) for noverlap=0)
w 	= hanning(m);	% Type of windowing: change this for application
			% (Try HAMMING, BLACKMAN, BARTLETT, or your own)
			% HANNING is best for narrow-band random !!
KMU 	= ns*norm(w)^2;	% Norm. scale factor (AVERAGING & WINDOWING)
index 	= 1:m;
fprintf(1,['\n%5i',' Samples Averaged\n'],ns)


%% Average auto- and cross-power spectra across frames
% FIND POWER SPECTRUMS OF EACH SAMPLE AND SUM
Pxx = zeros(m,1); Pyy = Pxx; Pxy = Pxx; 
for i = 1:ns
	xw 	= w.*detrend(x(index));		% detrend? no difference
	yw 	= w.*detrend(y(index));
	index 	= index + (m - noverlap);
	Xx 	= fft(xw);
	Yy 	= fft(yw);
	Pxx 	= Pxx + Xx.*conj(Xx);
	Pyy 	= Pyy + Yy.*conj(Yy);
	Pxy 	= Pxy + Yy.*conj(Xx);
end

%% Keep positive-frequency data and compute transfer function
% SELECT 
%select = [1:m/2];
select = 1:(m/2 + 1);   % include DC AND Nyquist
%FreqV	= [fs/2/(m/2):fs/2/(m/2):fs/2]';		% (Nyquist)
FreqV	= (select - 1)'*fs/m;
mcorrect	= round(.78*max(select));		% first 78% 
fcorrect	= FreqV(mcorrect);

% AVERAGED & SCALED DATA
Pxx = Pxx(select)./KMU;			% Double sided
Pyy = Pyy(select)./KMU;
Pxy = Pxy(select)./KMU;
P   = [Pxx,Pyy,Pxy];

Xfer21 	= Pxy./Pxx;
%keyboard

%% Plot Bode result when no outputs are requested
% NO OUTPUT ARGUMENTS, PLOT BODE
if (nargout == 0)

	subplot(211)
	plot(FreqV,db(Xfer21),color);grid
	% plot(FreqV,Xfer21,color);grid
	xlabel('Frequency (Hz)')
	ylabel('Gain (dB, dimensionless ratio)')
	title('Transfer Function')
	limits1	= axis;hold on
    limits1(2)=50;  % By me
    % limits1(3)=0;   % By me
    % limits1(4)=2;   % By me
    xlim([limits1(1), limits1(2)]); % Set the x-axis limits
	plot([fcorrect,fcorrect],[limits1(3),limits1(4)],'r');
	hold off

    subplot(212)
    plot(FreqV, ang(Xfer21), color);
    grid on;
    xlabel('Frequency (Hz)')
    ylabel('Phase (deg)')
    limits1 = xlim; % Get the current x-axis limits
    xlim([limits1(1), limits1(2)]); % Set the x-axis limits
    limits2 = axis;
    hold on
    plot([fcorrect, fcorrect], [limits2(3), limits2(4)], 'r');
    hold off

%	orient tall;print
	return % Suppress output

end

