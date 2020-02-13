
% MANUAL Allows for manual primary particle sizing on an array of aggregates.
% Modified by:  Timothy Sipkens, 2019-07-23
%   Pieces of this code are adapted from code by Ramin Dastanpour, 
%   Hugo Tjong, Arka Soewono from the University of British Columbia, 
%   Vanouver, BC, Canada. 
%=========================================================================%

function [Aggs,Data] = manual(Aggs,ind)

%-- Parse inputs ---------------------------------------------------------%
if ~exist('ind','var'); ind = []; end
if isempty(ind); ind = 1:length(Aggs); end
    % if ind was not specified, analyze all of the aggregates
%-------------------------------------------------------------------------%


disp('Performing manual analysis...');

%-- Check whether the data folder is available ---------------------------%
if exist('data','dir') ~= 7 % 7 if exist parameter is a directory
    mkdir('data') % make output folder
end

figure; % figure handle used during manual sizing


%== Process image ========================================================%
for ll = 1:length(ind) % run loop as many times as images selected
    
    Data = struct(); % re-initialize data structure
    
    pixsize = Aggs(ll).pixsize; % copy pixel size locally
    img_cropped = Aggs(ll).img_cropped;
    
    %== Step 3: Analyzing each aggregate =================================%
    bool_finished = 0;
    jj = 0; % intialize particle counter
    
    f = figure; % plot aggregate
    imshow(img_cropped);
    f.WindowState = 'maximized';
    hold on;
    
    uiwait(msgbox('Please select two points on the image that correspond to the length of the primary particle',...
        ['Process Stage: Length of primary particle ' num2str(jj)...
        '/' num2str(jj)],'help'));
    
    while bool_finished == 0

        jj = jj+1;
        [x,y] = ginput(2);
        
        Data.length(jj,1) = pixsize*sqrt((x(2)-x(1))^2+(y(2) - y(1))^2);
        line ([x(1),x(2)],[y(1),y(2)], 'linewidth', 3);
        
        [a,b] = ginput(2);
        
        Data.width(jj,1) = pixsize*sqrt((a(2)-a(1))^2+(b(2) - b(1))^2);
        line ([a(1),a(2)],[b(1),b(2)],'Color', 'r', 'linewidth', 3);
        
        %-- Save center of the primary particle --------------------------%
        Data.centers(jj,:) = find_centers(x,y,a,b);
        Data.radii(jj,:) = (sqrt((a(2)-a(1))^2+(b(2)-b(1))^2)+...
        	sqrt((x(2)-x(1))^2+(y(2)-y(1))^2))/4;
            % takes an average over drawn lines (given in pixels)
        Data.dp = 2.*pixsize.*Data.radii; % particle diameter (given in nm)
        
        %-- Check if there are more primary particles --------------------%
        choice = questdlg('Do you want to analyze another primary particle ?',...
        'Continue?','Yes','No','Yes');
        if strcmp(choice,'Yes')
        	bool_finished = 0;
        else
        	bool_finished = 1;
        end
        
    end
    
    Data = tools.refine_circles(img_cropped,Data);
        % allow for refinement of circles
    
    %== Save results =====================================================%
    %   Format output and autobackup data ------------------------%
    Aggs(ll).dp_manual_data = Data; % copy Dp data structure into img_data
    Aggs(ll).dp_manual = mean(Data.dp);
    save(['data',filesep,'manual_data.mat'],'Aggs'); % backup img_data
    
    close all;

end

Data = [Aggs.dp_manual_data];

disp('Complete.');
disp(' ');

end




%== FIND_CENTERS =========================================================%
%   Computes the intersection of the two lines to get particle center.
%   Author: Yeshun (Samuel) Ma, Timothy Sipkens, 2019-07-12
%
%   Notes:
%   x,y,a,b are single column vectors of two entries denoting the x or y
%   coordinate at the points the user had clicked on the image during
%   primary particle sizing.
%
%   Utilizes derived formulae to compute the intersection of the linear
%   functions composed of the provided parameters.  Returns center: a
%   two column vector corresponding to the x and y coordinates of the
%   primary particle
function centers = find_centers(x,y,a,b)

tol = 1e-10; % used to prevent division by zero

%-- Initialize xy parameters ---------------------------------------------%
x1 = x(1);
x2 = x(2);
if x1==x2; x1 = x1+tol; end % prevents division by zero
y1 = y(1);
y2 = y(2);
if y1==y2; y1 = y1+tol; end % prevents division by zero

%-- Initialize ab parameters ---------------------------------------------%
a1 = a(1);
a2 = a(2);
if a1==a2; a1 = a1+tol; end % prevents division by zero
b1 = b(1);
b2 = b(2);
if b1==b2; b1 = b1+tol; end % prevents division by zero

%-- Compute slopes -------------------------------------------------------%
m = (y1-y2)./(x1-x2);    % For xy line (vectorized)
n = (b1-b2)./(a1-a2);    % For ab line
if any(m==n); m = m+tol; end % prevents division by zero

%-- Assign appropriate fields and return ---------------------------------%
centers(1,:) = (b1-y1-n.*a1+m.*x1)./(m-n); % x-coordinate
centers(2,:) = (centers(1,:)-a1).*n+b1; % y-coordinate

end



