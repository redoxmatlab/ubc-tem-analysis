
% SEG_SLIDER Performs background correction and manual thresholding on a user-defined portion of the image.
% Author:       Ramin Dastanpour, Steven N. Rogak, 2016-02 (originally)
%               Developed at the University of British Columbia
% Modified:     Tmothy Sipkens, 2019-10-11
%=========================================================================%

function [img_binary,rect,img_refined,img_cropped] = seg_slider(img,bool_crop) 

%== Parse input ==========================================================%
if ~exist('bool_crop','var'); bool_crop = []; end
if isempty(bool_crop); bool_crop = 1; end
%=========================================================================%


img_binary = []; % declare nested variable (allows GUI feedback)


%== STEP 1: Crop image ===================================================%
if bool_crop
    uiwait(msgbox('Please crop the image around missing particle'));
    [img_cropped,rect] = imcrop(img); % user crops image
else
	img_cropped = img; % originally bypassed in Kook code
    rect = [];
end


%== STEP 2: Image refinment ==============================================%
%-- Step 1-1: Apply Lasso tool -------------------------------------------%
img_binary = lasso_fnc(img_cropped);

%-- Step 1-2: Refining background brightness -----------------------------%
img_refined = background_fnc(img_binary,img_cropped);



%== STEP 3: Thresholding =================================================%
f = figure;
screen_size = get(0,'Screensize');
set(f,'Position',screen_size); % maximize figure
% f.WindowState = 'maximized'; % maximize figure

hax = axes('Units','Pixels');
imshow(img_refined);

level = graythresh(img_refined); % Otsu thresholding
hst = uicontrol('Style', 'slider',...
    'Min',0-level,'Max',1-level,'Value',.5-level,...
    'Position', [20 390 150 15],...
    'Callback', {@thresh_slider,hax,img_refined,img_binary});
get(hst,'value'); % add a slider uicontrol

uicontrol('Style','text',...
    'Position', [20 370 150 15],...
    'String','Threshold level');
        % add a text uicontrol to label the slider

%-- Pause program while user changes the threshold level -----------------%
h = uicontrol('Position',[20 320 200 30],'String','Finished',...
    'Callback','uiresume(gcbf)');
message = sprintf('Move the slider to the right or left to change threshold level\nWhen finished, click on continute');
uiwait(msgbox(message));
disp('Waiting for the user to apply the threshold to the image');
uiwait(gcf);
close(gcf);
disp('Thresholding is applied.');


%== STEP 4: Select particles and format output ===========================%
uiwait(msgbox('Please selects (left click) particles satisfactorily detected; and press enter'));
img_binary = bwselect(img_binary,8);
close(gcf);
img_binary = ~img_binary; % formatted for PCA, other codes should reverse this




%== Sub-functions ==% 
%=========================================================================%
%== BACKGROUND_FNC =======================================================%
% Smooths out background using curve fitting
% Author:    Ramin Dastanpour, Steven N. Rogak, Last updated in Feb. 2016
% Modified:  Timothy Sipkens, 2019-07-16
%
% Notes:
%   This function smoothens background brightness, specially on the edges of
%   the image where intensity (brightness) has a curved planar distribution.
%   This improves thresholding in the following steps of image processing

function img_refined = background_fnc(img_binary,img_cropped)

nagg = nnz(img_binary); % pixels within the aggregate
ntot = numel(img_cropped); % pixels within the whole cropped image 
nbg = ntot-nagg; % pixels in the backgound of the aggregate


%-- Computing average background intensity -------------------------------%
burned_img = img_cropped;
burned_img(img_binary) = 0;
mean_bg =  mean(mean(burned_img))*ntot/nbg;


%-- Replace aggregate pixels' with intensity from the background ---------%
img_bg = img_cropped;
img_bg(img_binary) = mean_bg;


%-- Fit a curved surface into Filled_img data ----------------------------%
[x_d,y_d] = meshgrid(1:size(img_bg,2),1:size(img_bg,1));
xdata = {x_d,y_d};
fun = @(c,xdata) c(1).*xdata{1}.^2+c(2).*xdata{2}.^2+c(3).*xdata{1}.*xdata{2}+...
    c(4).*xdata{1}+c(5).*xdata{2}+c(6);

c_start = [0 0 0 0 0 mean_bg];
options = optimset('MaxFunEvals',1000);
options = optimset(options,'MaxIter',1000); 
[c] = lsqcurvefit(fun,c_start,xdata,double(img_bg),[],[],options);

%-- Build the fitted surface ---------------------------------------------%
img_bg_fit = zeros(size(img_bg));
for ii = 1:size(img_bg,1)
    for jj = 1:size(img_bg,2)
        img_bg_fit(ii,jj) = ...
            c(1)*ii^2+c(2)*jj^2+c(3)*ii*jj+c(4)*ii+c(5)*jj+c(6);
    end
end

%-- Refine Cropped_img, using fitted surface -----------------------------%
img_refined = mean_bg+double(img_cropped)-img_bg_fit;
img_refined = uint8(img_refined);

end




%=========================================================================%
%== LASSO_FNC ============================================================%
%   This function allows user to draw an approximate boundary around the
%   particle. Region of interest (ROI))
%   Author:   Ramin Dastanpour & Steven N. Rogak
%             Developed at the University of British Columbia
%   Modified: Yiling Kang, 2018-05-10
%             Timothy Sipkens
% 
%   Yiling Kang updates/QOL changes:
%   - Asks user if their lasso selection is correct before applying the
%     data
%   - QOL - User will not have to restart program if they mess up the lasso

function binaryImage = lasso_fnc(Cropped_im)

fontsize = 10;

%-- Displaying cropped image ---------------------------------------------%
figure; imshow(Cropped_im);
title('Original CROPPED Image', 'FontSize', fontsize);
set(gcf, 'Position', get(0,'Screensize')); % Maximize figure.

%-- Freehand drawing. Selecting region of interest (ROI) -----------------%
drawing_correct = 0; % this variable is used to check if the user drew the lasso correctly
while drawing_correct == 0 
    message = sprintf('Please draw an approximate boundary around the aggregate.\nLeft click and hold to begin drawing.\nLift mouse button to finish');
    uiwait(msgbox(message));
    hFH = imfreehand(); % alternate for MATLAB 2019b+: drawfreehand();
    finished_check = questdlg('Are you satisfied with your drawing?','Lasso Complete?','Yes','No','No');
    
    % if user is happy with their selection...
    if strcmp(finished_check, 'Yes')
        drawing_correct = 1;
    % if user would like to redo their selection...
    else
        delete(hFH);
    end     
end


%-- Create a binary masked image from the ROI object ---------------------%
binaryImage = hFH.createMask();


end




%=========================================================================%
%== THRESH_SLIDER ========================================================%
%   Thresholding the image using a slider GUI
%   Function to be used with the pair correlation method (PCM) package
%   Author:   Ramin Dastanpour & Steven N. Rogak, 2016-02
%             Developed at the University of British Columbia
%   Modified: Timothy Sipkens

function thresh_slider(hObj,event,hax,thresh_slider_in,binaryImage)

%-- Average filter -------------------------------------------------------%
hav = fspecial('average');
img_filtered = imfilter(thresh_slider_in, hav);


%-- Median ---------------------------------------------------------------%
% Examines a neighborhood of WxW matrix, takes and makes the centre of that
% matrix the median of the original neighborhood
W = 5;
thresh_slider_in = img_filtered;
for ii=1:8 % repeatedly apply median filter
    thresh_slider_in = medfilt2(thresh_slider_in,[W W]);
end
% NOTE: The loop is intended to imitate the increasing amounts of 
% median filter that is applied each time the slider button is clicked
% in the original code. This was a bug in the previous software. 


%-- Binary image via threshold value -------------------------------------%
adj = get(hObj,'Value');
level = graythresh(thresh_slider_in);
level = level+adj;
img_binary1 = imbinarize(thresh_slider_in,level);


%-- Binary image via dilation --------------------------------------------%
%   Reduces initial noise and fill initial gaps
SE1 = strel('square',1);
img_binary2 = imdilate(~img_binary1,SE1);


%-- Refining binary image. Before refinig, thresholding causes some ------%
%   Errors, initiating from edges, grows towards the aggregate. In
%   this section, external boundary, or background region, is utilized to
%   eliminate detection errors in the background region.
img_binary3 = 0.*img_binary2;
img_binary3(binaryImage) = img_binary2(binaryImage);
img_binary = logical(img_binary3);

img_temp2 = imimposemin(thresh_slider_in,img_binary);

axes(hax);
imshow(img_temp2);

end

img_binary = ~img_binary;

end