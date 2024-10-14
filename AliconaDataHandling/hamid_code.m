clear;
clc;
close all;

%% Lecture et Analyser des donn�es brutes issue de l Alicona
Data = AliconaReader(); %Lire les donn�es
%D�tecter et remplacer les donn�es aberrantes
Z_Data = double(filloutliers(Data.DepthData,'nearest','median')); 
[X,Y] = meshgrid(1:1:length(Data.DepthData));
[xData, yData, zData] = prepareSurfaceData( X, Y, Z_Data ); %pr�paration
% des donn�es � traiter avec fit Xdata, Ydata et Zdata en 1 seul colonne 
% Configurer le fittype et les diff�rentes param�tre.
ft = fittype( 'poly11' ); %Constrution des types d'ajustement en 
% sp�cifiant le mod�les, "poly11 = Surface polynomiale lin�aire" .
% Ajustement du mod�le aux donn�es.
fitresult= fit( [xData, yData], zData, ft );
% affichage du plan avec les donn�es. 
figure( 'Name', 'Depth_fit' );
hold on
mesh(Z_Data)
colorbar
plot( fitresult);
hold off

%% Degauchissage du nuage de points

%Exportez les param�tres de l'�quation du plan (Z=a*x+b*y+c)
paramtr=coeffvalues(fitresult);
% c=paramtr(1); a=paramtr(2); b=paramtr(3);
plan_Z_eq = paramtr(2)*X + paramtr(3)*Y + paramtr(1);
%Calcule de la distance entre le plan et la surface obtenue
Z_data_H = Z_Data - plan_Z_eq; 
%Affichage de la surface suivante un plan Horizontal
figure ;
mesh(Z_data_H)
colorbar;

%% Calcul des param�tres d��tats de surface surfacique

%Sp : Hauteur du pic maximale de la surface 
Sp = max(Z_data_H(:));
%Sv : profondeur maximale de creux.
Sv = abs(min(Z_data_H(:)));
%Sz,Amplitude maximale de la surface.
Sz = Sp + Sv ;
%Rugosite moyenne arithmetique des hauteurs Z(x,y).
Sa = mean(mean(abs(Z_data_H)));
%Rugosite moyenne quadratique des valeurs des hauteurs Z (x, y).
Sq = sqrt(sum(sum(Z_data_H.^2))/length(Z_data_H)^2);
%Ssk : Facteur d'asym�trie de la surface 
Ssk = (mean(mean((Z_data_H.^3)))/Sq^3); 
%Sku : Facteur d'aplatissement de la furface
Sku = (mean(mean((Z_data_H.^4)))/Sq^4); 
mask = imregionalmax(Z_data_H);
% Sds : Nombre de pics par unite d'aire.
Sds = floor(length(find(mask(:,:)==1))/ ...
    (str2double(Data.Header.PixelSizeYMeter)*length(Z_data_H))^2);

%% Filtrage (Filtre de Gauss) Le filtre gaussien est un type de filtre de lissage qui supprime le bruit en utilisant la fonction gaussienne.
tic()
% Filter Gausse par conv2 (Methode  1)
%Cr�ation d'une matrice gaussienne comme filtre.
FGauss = fspecial('gaussian',[3 3],0.9);
%Calcul de la matrice, 'same' d�signe m�me taille que Z_data.
Z_data_FG= conv2(Z_data_H,FGauss,'same'); 
figure;
mesh(Z_data_FG);
colorbar('Ticks',[-0.0002,-0.0001,0,0.0001,0.0002]);
% Nombre de pics par unite d'aire.
Sdk_FG = floor(length(find(mask(:,:)==1))/ ...
    (str2double(Data.Header.PixelSizeYMeter)*length(Z_data_H))^2)
toc()
%Methode 2.
Z_data_FG = imgaussfilt(Z_data_H,0.9,"FilterSize",3); 


%% Autre Filtre (Filter de moyenne par convolution)
tic()
% pr�paration du filtre de moyenne de taille 3x3.
filter_moyenne = fspecial('average',[3 3]); 
% Le filtrage en utilisant la convolution.
FMoyenne_Z = imfilter(Z_data_H,filter_moyenne,'conv'); 
figure; 
mesh(FMoyenne_Z);
colorbar('Ticks',[-0.0002,-0.0001,0,0.0001,0.0002]);
mask = imregionalmax(FMoyenne_Z);
Sdk_FM = floor(length(find(mask(:,:)==1))/ ...
    (str2double(Data.Header.PixelSizeYMeter)*length(Z_data_H))^2);
toc()
%% filtre morphologiques
%https://fr.mathworks.com/help/images/morphological-filtering.html?s_tid=CRUX_topnav
%https://guide.digitalsurf.com/fr/guide-techniques-filtrage.html
%https://fr.mathworks.com/help/images/ref/offsetstrel.html
tic() ;
% dilatation
rayon = 3 ;  %rayon de la sphere en m�tre.
h = 3 ;  % hauteur � afficher de la demi-sphere  
%cr�ation d'un �l�ment structurant en forme de sph�re de 
% rayon r et dont la hauteur maximale est h.
SE = offsetstrel('ball',rayon,h);
%matrice de projection de la demi-sphere sur le plan
Sphere= (ones(length(SE.Offset),length(SE.Offset))* ...
    max(SE.Offset(:))-SE.Offset)*1e-6 ;
p=floor(length(Sphere)/2);
Offset = Z_data_H;  %d�claration de la matrice d'offset par dilataion 
%la matrice sur la quelle on va prendre des imagettes
matrice_base = padarray(Z_data_H,[p p],-9e-10,'both');  
for i=p+1:length(Z_data_H)-p
    for j=p+1:length(Z_data_H)-p
        im0=matrice_base(i-p:i+p,j-p:j+p); % Extraction de l'imagette
        S = Sphere + Z_data_H(i,j);  %Matrice repr�sent le contact entre 
        % la sphere et la surface 
        test = im0 >= S ;  % Matrice test si il y a un d�passement 
        % de la surface et la sph�re
        if max(test(:))==1 %pr�sence d'un d�passement
            Offset(i,j)=Offset(i,j)+max(max(im0-S)); 
        end
    end
end
mask = imregionalmax(Offset);
mesh(Offset);
%colorbar('Ticks',[-0.0002,-0.0001,0,0.0001,0.0002]);
% Nombre de pics par unit� d'aire.
Sdk_FMor = length(find(mask(:,:)==1))/...
(str2double(Data.Header.PixelSizeYMeter)*length(Z_data_H))^2;

toc()

