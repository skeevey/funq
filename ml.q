\d .ml

mm:mmu                          / X  * Y
mmt:{y$/:x}                     / X  * Y'
mtm:{flip[x]$y}                 / X' * Y
minv:inv                        / X**-1
mlsq:lsq                        / least squares
dot:$                           / dot product

prepend:{((1;count y 0)#x),y}
append:{y,((1;count y 0)#x)}
addint:prepend[1f]              / add intercept

predict:{[X;THETA]mm[THETA] addint X} / regression predict

/ regularized linear regression cost
rlincost:{[l;X;Y;THETA]
 J:sum (1f%2*n:count Y 0)*sum mmt[Y] Y-:predict[X;THETA];
 if[l>0f;J+:(l%2*n)*dot[x]x:raze @[;0;:;0f]'[THETA]];
 J}
lincost:rlincost[0f]

/ regularized linear regression gradient
rlingrad:{[l;X;Y;THETA]
 g:(1f%n:count Y 0)*mmt[predict[X;THETA]-Y] addint X;
 if[l>0f;g+:(l%n)*@[;0;:;0f]'[THETA]];
 g}
lingrad:rlingrad[0f]

/ regularized content-based filtering cost & gradient
rcbfcostgrad:{[l;X;Y;theta]
 THETA:(count Y;0N)#theta;
 J:.5*sum sum 0f^J*J:predict[X;THETA]-Y;
 if[l>0f;J+:(.5*l)*dot[x]x:raze @[;0;:;0f]'[THETA]];
 g:mmt[0f^predict[X;THETA]-Y] addint X;
 if[l>0f;g+:l*@[;0;:;0f]'[THETA]];
 (J;raze g)}
cbfcostgrad:rcbfcostgrad[0f]

/ regularized collaborative filtering cost
rcfcost:{[l;Y;THETA;X]
 J:.5*sum sum 0f^J*J:mtm[THETA;X]-Y;
 if[l>0f;J+:.5*l*sum sum over/:(THETA*THETA;X*X)];
 J}
cfcost:rcfcost:[0f]

/ regularized collaborative filtering gradient
rcfgrad:{[l;Y;THETA;X]
 g:(mmt[X;g];mm[THETA] g:0f^mtm[THETA;X]-Y);
 if[l>0f;g+:l*(THETA;X)];
 g}
cfgrad:rcfgrad[0f]

/ collaborative filtering cut where n:(nu;nf)
cfcut:{[n;x](n[1],0N)#/:(0,prd n)_x}

/ regularized collaborative filtering cost & gradient
rcfcostgrad:{[l;Y;n;thetax]
 THETA:first X:cfcut[n] thetax;X@:1;
 J:.5*sum sum g*g:0f^mtm[THETA;X]-Y;
 g:(mmt[X;g];mm[THETA;g]);
 if[l>0f;J+:.5*l*sum sum over/:(THETA*THETA;X*X);g+:l*(THETA;X)];
 (J;2 raze/ g)}
cfcostgrad:rcfcostgrad[0f]

/ regularized collaborative filtering update one rating
/ (a)lpha: learning rate, (xy): coordinates of Y to update
rcfupd1:{[l;Y;a;THETAX;xy]
 e:(Y . xy)-dot . tx:THETAX .'i:flip(::;xy);
 THETAX:./[THETAX;0 1,'i;+;a*(e*reverse tx)-l*tx];
 THETAX}

/ accumulate cost by calling (c)ost (f)unction on the result of
/ (f)unction applied to x[1].  append resulting cost to x[0] and
/ return.
acccost:{[cf;f;x] (x[0],cf fx;fx:f x 1)}

/ return 1b until the improvement from the (c)ost is less than
/ the specified (p)ercent.
converge:{[p;c]
 b:$[1<n:count c;p<pct:neg -1f+c[n-1]%c[n-2];1b];
 1"Iteration ",string[n]," | cost: ",string[last c]," | pct: ",string[pct],"\n\r"b;
 b}

/ (a)lpha: learning rate, gf: gradient function
gd:{[a;gf;THETA] THETA-a*gf THETA} / gradient descent

normeq:{mm[mmt[x;y]] minv mmt[y;y]} / normal equations

/ apply f (in parallel) to the 2nd dimension of x (instead of flipping x)
f2nd:{[f;x](f x .(::),) peach til count first x}
/ center data
demean:{x-\:$[type x;avg;f2nd avg] x}
/ apply f to centered (then decenter)
fdemean:{[f;x]a+f x-\:a:$[type x;avg;f2nd avg] x}
/ feature normalization (centered/unit variance)
zscore:{x%\:$[t;sdev;f2nd sdev] x:x-\:$[t:type x;avg;f2nd avg] x}
/ apply f to normalized (then denormalize)
fzscore:{[f;x]a+d*f x%\:d:$[t;sdev;f2nd sdev]x:x-\:a:$[t:type x;avg;f2nd avg] x}

/ compute the average of the top n items
navg:{[n;x;y]f2nd[avg] y (n&count x)#idesc x}
/ compute the weighted average of the top n items
nwavg:{[n;x;y]sum[0^x*y i]%sum abs x@:i:(n&count x)#idesc x}

/ user-user collaborative filtering
/ (s)imilarity (f)unction, (a)veraging (f)unction
/ (R)ating matrix and new (r)ating vector
uucf:{[sf;af;R;r]af[sf[r] peach R;R]}

/ spearman's rank (tied value get averaged rank)
/srank:{(avg each rank[x] group x) x}
srank:{@[r;g;:;avg each (r:"f"$rank x) g@:where 1<count each g:group x]}
/ where not any null
wnan:{$[any 1_differ type each x;til count x;where not any null x]}
/ spearman's rank correlation
scor:{srank[x w] cor srank y w:wnan(x;y)}

sigmoid:{1f%1f+exp neg x}       / sigmoid function

lpredict:(')[sigmoid;predict]   / logistic regression predict

/ logistic regression cost
lcost:{sum (-1f%count y 0)*sum each (y*log x)+(1f-y)*log 1f-x}

/ regularized logistic regression cost
/ expects a list of THETA matrices
rlogcost:{[l;X;Y;THETA]
 if[type THETA  ;:.z.s[l;X;Y] enlist THETA];     / vector
 if[type THETA 0;:.z.s[l;X;Y] enlist THETA];     / single matrix
 J:lcost[X lpredict/ THETA;Y];
 if[l>0f;J+:(l%2*count Y 0)*dot[x]x:2 raze/ @[;0;:;0f]''[THETA]]; / regularization
 J}
logcost:rlogcost[0f]

/ regularized logistic regression gradient
/ expects a list of THETA matrices
rloggrad:{[l;X;Y;THETA]
 if[type THETA  ;:first .z.s[l;X;Y] enlist THETA]; / vector
 if[type THETA 0;:first .z.s[l;X;Y] enlist THETA]; / single matrix
 n:count Y 0;
 a:lpredict\[enlist[X],THETA];
 D:last[a]-Y;
 a:addint each -1_a;
 D:{[D;THETA;a]1_(mtm[THETA;D])*a*1f-a}\[D;reverse 1_THETA;reverse 1_a],enlist D;
 g:(D mmt' a)%n;
 if[l>0f;g+:(l%n)*@[;0;:;0f]''[THETA]]; / regularization
 g}
loggrad:rloggrad[0f]

rlogcostgrad:{[l;X;Y;THETA]
 J:sum rlogcost[l;X;Y;THETA];
 g:rloggrad[l;X;Y;THETA];
 (J;g)}
logcostgrad:rlogcostgrad[0f]

rlogcostgradf:{[l;X;Y]
 Jf:(sum rlogcost[l;X;Y]@);
 gf:(enlist rloggrad[l;X;Y]@);
 (Jf;gf)}
logcostgradf:rlogcostgradf[0f]

/ normalized initialization - Glorot and Bengio (2010)
ninit:{sqrt[6f%x+y]*-1f+(x+:1)?/:y#2f}

/ (m)inimization (f)unction, (c)ost (g)radient (f)unction
onevsall:{[mf;cgf;Y;lbls] (mf cgf "f"$Y=) peach lbls}

imax:{x?max x}                  / index of max element
imin:{x?min x}                  / index of min element

/ predict each number and pick best
predictonevsall:{[X;THETA]f2nd[imax] X lpredict/ THETA}

/ binary classification evaluation metrics (summary statistics)

/ given expected boolean values x and observered value y, compute
/ (tp;tn;fp;fn)
tptnfpfn:{sum each (x;nx;x;nx:not x)*(y;ny;ny:not y;y)}

/ aka rand measure (William M. Rand 1971)
accuracy:{sum[x 0 1]%sum x}
precision:{x[0]%sum x 0 2}
recall:{x[0]%sum x 0 3}

/ f measure: given (b)eta and x:tptnfpfn
/ harmonic mean of precision and recall
F:{[b;x]
 f:(p:precision x)*(r:recall x)*1+b2:b*b;
 f%:r+p*b2;
 f}
F1:F[1]

/ Fowlkes–Mallows index (E. B. Fowlkes & C. L. Mallows 1983)
/ geometric mean of precision and recall
FM:{x[0]%sqrt sum[x 0 2]*sum x 0 3}

/ returns a number between 0 and 1 which indicates the similarity
/ between two datasets
jaccard:{x[0]%sum x _ 1}

/ Matthews Correlation Coefficient
/ geometric mean of the regression coefficients of the problem and its dual
/ -1 0 1 (none right, same as random prediction, all right)
MCC:{ ((-). x[0 2]*x 1 3)%prd sqrt x[0 0 1 1]+x 2 3 2 3}

/ confusion matrix
cm:{
 n:count u:asc distinct x,y;
 m:./[(n;n)#0;flip (u?y;u?x);1+];
 t:([]x:u)!flip (`$string u)!m;
 t}

/ neural network cut
nncut:{[n;x](1+-1_n) cut' (sums {x*y+1} prior -1_n) cut x}
diag:{$[0h>t:type x;x;@[n#abs[t]$0;;:;]'[til n:count x;x]]}

/ (f)unction, x, (e)psilon
/ compute partial derivatives if e is a list
numgrad:{[f;x;e](.5%e)*{x[y+z]-x[y-z]}[f;x] peach diag e}

checknngradients:{[l;n]
 theta:2 raze/ THETA:ninit'[-1_n;1_n];
 X:flip ninit[-1+n 0;n 1];
 y:1+(1+til n 1) mod last n;
 YMAT:flip diag[last[n]#1f]"i"$y-1;
 g:2 raze/ rloggrad[l;X;YMAT] THETA; / analytic gradient
 f:(rlogcost[l;X;YMAT]nncut[n]@);
 ng:numgrad[f;theta] count[theta]#1e-4; / numerical gradient
 (g;ng)}

checkcfgradients:{[l;n]
 nu:n 0;nm:n 1;nf:n 2;          / n users, n movies, n features
 Y:dot[nf?/:nu#1f]nm?/:nf#1f;   / random recommendations
 Y*:0N 1@.5<nm?/:nu#1f;         / drop some recommendations
 thetax:2 raze/ (THETA:nu?/:nf#1f;X:nm?/:nf#1f); / random initial parameters
 g:2 raze/ rcfgrad[l;Y;THETA;X];                 / analytic gradient
 f:(rcfcost[l;Y] . cfcut[n]@);
 ng:numgrad[f;thetax] count[thetax]#1e-4; / numerical gradient
 (g;ng)}


/ n can be any network topology dimension
nncostgrad:{[l;n;X;YMAT;theta] / combined cost and gradient for efficiency
 THETA:nncut[n] theta;
 Y:last a:lpredict\[enlist[X],THETA];
 n:count YMAT 0;
 J:lcost[Y;YMAT];
 if[l>0f;J+:(l%2*n)*{dot[x]x}2 raze/ @[;0;:;0f]''[THETA]]; / regularization
 D:Y-YMAT;
 a:addint each -1_a;
 D:{[D;THETA;a]1_mtm[THETA;D]*a*1f-a}\[D;reverse 1_THETA;reverse 1_a],enlist D;
 g:(D mmt' a)%n;
 if[l>0f;g+:(l%n)*@[;0;:;0f]''[THETA]]; / regularization
 (J;2 raze/ g)}

nncostgradf:{[l;n;X;YMAT]
 Jf:(first nncostgrad[l;n;X;YMAT]@);
 gf:(last nncostgrad[l;n;X;YMAT]@);
 (Jf;gf)}

/ stochastic gradient descent

/ successively call (m)inimization (f)unction with (THETA) and
/ randomly sorted (n)-sized chunks generated by (s)ampling (f)unction
sgd:{[mf;sf;n;X;THETA]THETA mf/ n cut sf count X 0}

/ (w)eighted (r)egularized (a)lternating (l)east (s)quares
wrals:{[l;Y;THETAX]
 X:THETAX 1;
 THETA:flip updals[l;X] peach Y;
 X:flip f2nd[updals[l;THETA]] Y;
 (THETA;X)}
updals:{[l;M;y]
 l:diag count[M:M[;w]]#l*count w:where not null y;
 v:first mlsq[enlist mm[M;y w]] mmt[M;M]+l;
 v}

/ k-means

edist:{sqrt sum x*x-:y}         / euclidian distance
mdist:{sum abs x-y}             / manhattan distance (taxicab metric)
mkdist:{sum[abs[z-y] xexp x] xexp 1f%x} / minkowski distanace
hmean:{1f%avg 1f%x}             / harmonic mean

lntf:{1f+log x}                    / log normalized term frequency
dntf:{[k;x]k+(1f-k)*x% max each x} / double normalized term frequenecy

idf: {log count[x]%sum 0<x}     / inverse document frequency
idfs:{log 1f+count[x]%sum 0<x}  / inverse document frequency smooth
idfm:{log 1f+max[x]%x:sum 0<x}  / inverse document frequency max
pidf:{log (max[x]-x)%x:sum 0<x} / probabilistic inverse document frequency
tfidf:{[tff;idff;x]tff[x]*\:idff x}
cossim:{(sum x*y)%sqrt(sum x*x@:w)*sum y*y@:w:wnan(x;y)} / cosine similarity
cosdist:(')[1f-;cossim]                  / cosine distance

/ using the (d)istance (f)unction, cluster the data (X) into groups
/ defined by the closest (C)entroid
cgroup:{[df;X;C] group f2nd[imin] f2nd[df X] C}

/ return the index of n (w)eighted samples
iwrand:{[n;w]s binr n?last s:sums w}
/ find n (w)eighted samples of x
wrand:{[n;w;x]x iwrand[n] w}

/ kmeans++ initialization algorithm
/ using (d)istance (f)function and data X, append the next cluster
/ to the pair (min cluster (d)istance;all (C)lusters)
kmeanspp:{[df;X;dC]
 d:dC[0]&d*d:df[X] last C:dC 1;
 C,:enlist X@\: first iwrand[1] d;
 (d;C)}

/ k-(means|medians) algorithm

/ stuart lloyd's algorithm. using a (d)istance (f)unction and
/ (m)ean/edian (f)unction, find (k)-centroids in the data (X) starting
/ with a (C)entroid list. if C is an atom, use it to randomly
/ initialize C. if positive, use k-means++ method to pick k centroids
/ that are purposefully distant from each other. if negative, use
/ "Forgy" method and randomly pick k centroids.
lloyd:{[df;mf;X;C]
 if[not t:type C;C:cgroup[df;X;C];t:99h]; / assign step
 if[99h=t;:mf''[X@\:value C]];            / update step
 if[0>C;:X@\:C?count X 0];                / forgy
 C:flip last (C-1) kmeanspp[df;X]/ (df[X] c;enlist c:X@\:rand count X 0);
 C}

kmeans:lloyd[edist;avg]
kmedians:lloyd[mdist;med]
khmeans:lloyd[edist;hmean]

/ using the (d)istance (f)unction, cluster the data (X) into groups
/ defined by the closest (C)entroid and return the distance
cdist:{[df;X;C] k!df[X@\:value g] C@\:k:key g:cgroup[df;X;C]}
ecdist:cdist[edist]
mcdist:cdist[mdist]

distortion:sum sum each

/ ungroup (inverse of group)
ugrp:{(key[x] where count each value x)iasc raze x}

/ lance-williams algorithm update functions
single:{.5 .5 0 -.5}
complete:{.5 .5 0 .5}
average:{(x%sum x _:2),0 0f}
weighted:{.5 .5 0 0}
centroid:{((x,neg prd[x]%s)%s:sum x _:2),0f}
ward:{((k+/:x 0 1),(neg k:x 2;0f))%\:sum x}

/ implementation of lance-williams algorithm for performing
/ hierarchical agglomerative clustering. given (l)inkage (f)unction to
/ determine distance between new and remaining clusters and
/ (d)issimilarity (m)atrix, return (from;to;distance;#elements).  lf
/ in `single`complete`average`weighted`centroid`ward
lw:{[lf;dm]
 n:count dm 0;
 if[0w=d@:i:imin d:(n#dm)@'dm n;:dm]; / find closest clusters
 j:dm[n] i;                           / find j
 c:lf (count each group dm[n+1])@/:(i;j;til n); / determine coefficients
 nd:sum c*nd,d,enlist abs(-/)nd:dm(i;j);        / calc new distances
 dm[til n;i]:dm[i]:nd;                          / update distances
 dm[i;i]:0w;                                    / fix diagonal
 dm[j;(::)]:0w;                                 / erase j
 dm[til n+2;j]:(n#0w),i,i;    / erase j and set aux data
 dm[n]:imin peach n#dm;       / find next closest element
 dm[n+1;where j=dm n+1]:i;    / all elements in cluster j are now in i
 dm:@[dm;n+2 3 4 5;,;(j;i;d;count where i=dm n+1)];
 dm}

/ given a (d)istance (f)unction and (l)inkage (f)unction, construct the
/ linkage (dendrogram) statistics of data in X
linkage:{[df;lf;X]
 dm:f2nd[df X] X;                         / dissimilarity matrix
 dm:./[dm;flip (i;i:til count X 0);:;0w]; / ignore loops
 dm,:enlist imin peach dm;
 dm,:enlist til count dm 0;
 dm,:4#();
 l:-4#lw[lf] over dm;
 l}

/ merge node y[0] into y[1] in tree x
graft:{@[x;y;:;(::;x y)]}

/ build a complete dendrogram from linkage data x
tree:{1#(til[1+count x],(::)) graft/ x}

/ cut a single layer off tree
slice:{$[type x;x;type f:first x;(1_x),f;type ff:first f;(1_f),(1_x),ff;f,1_x]}

/ binomial pdf (not atomic because of factorial)
binpdf:{[n;p;k]
 if[0<max type each (n;p;k);:.z.s'[n;p;k]];
 r:prd[1+k+til n]%prd 1+til n-:k;
 r*:prd (p;1f-p) xexp (k;n);
 r}

/ binomial log likelihood (for multinomial set n=0)
binll:{[n;p;k](k*log p)+$[n;(n-k)*log 1f-p;0f]}
/ binomial likelihood approximation (without the coefficient)
binla:{[n;p;k](p xexp k)*$[n;(1f-p) xexp n-k;1f]}
/ binomial maximum likelihood
binml:{[n;x;w]$[type x;1#w wavg x%n;x .z.s[n]\: w]}

/ multinomial log likelhood
multill:binll[0]
/ multinomial likelihood approximation
multila:binla[0]
/ multinomial maximum likelihood (where n is for add n smoothing)
multiml:{[n;x;w]$[type x;1#w wsum x%n;(x:x,'n) .z.s[sum/[x]]\: w,1f]}
/ gaussian kernel
gaussk:{[mu;s2;x] exp (sum x*x-:mu)%-2*s2}

/ gaussian
gauss:{[mu;s2;x]
 p:exp (x*x-:mu)%-2*s2;
 p%:sqrt 2f*s2*acos -1f;
 p}

/ gaussian multivariate
gaussmv:{[mu;s2;X]
 if[type s2;s2:diag count[X]#s2];
 p:exp -.5*sum X*mm[minv s2;X-:mu];
 p*:sqrt 1f%.qml.mdet s2;
 p*:(2f*acos -1f) xexp -.5*count X;
 p}

/ gaussian maximum likelihood
gaussml:{[x;w]$[type x;(mu;w wavg x*x-:mu:w wavg x);x .z.s\: w]}
/ gaussian maximum likelihood multi variate
gaussmlmv:{[X;w](mu;w wavg X (*\:/:)' X:flip X-mu:w wavg/: X)}

/ guassian log likelihood
gaussll:{[mu;s2;X] -.5*sum (log 2f*acos -1f;log s2;(X*X-:mu)%s2)}

/ (l)ikelhood (f)unction, (m)aximization (f)unction
/ with prior probabilities (p)hi and distribution parameters (t)heta
em:{[lf;mf;X;pt]
 if[0h>type pt;pt:enlist pt#1f%pt]; / default to equal prior probabilities
 l:$[1<count pt;{(x . z) y}[lf;X] peach flip 1_pt;count[$[type X;X;X 0]]?/:count[pt 0]#1f];
 W:p%\:sum p:l*phi:pt 0;         / weights (responsibilities)
 if[0h<type phi;phi:avg peach W]; / new prior probabilities (if phi is a list)
 theta:flip mf[X] peach W;       / new coefficients
 enlist[phi],theta}

/ return value which occur most frequently
/mode:{imax count each group x}
mode:{x -1+w imax deltas w:where differ[x:asc x],1b}

/ k nearest neighbors

/ pick k closest values to x from training data X and return the
/ (c)lassification that occurs most frequently
knn:{[df;k;c;X;x]mode c k#iasc df[X;x]}

/ markov clusetering

addloop:{x|diag max peach x|flip x}

expand:{[e;X](e-1)mm[X]/X}

inflate:{[r;p;X]
 X:X xexp r;                             / inflate
 X*:$[-8h<type p;(p>iasc idesc@)';p<] X; / prune
 X%:sum peach X;                         / normalize
 X}

/ if (p)rune is an integer, take p largest, otherwise take everything > p
mcl:{[e;r;p;X] inflate[r;p] expand[e] X}

chaos:{max {max[x]-sum x*x} peach x}
interpret:{1_asc distinct f2nd[where] 0<x}

/ naive bayes

/ fit parameters given (m)aximization (f)unction
/ returns a dictionary with prior and conditional likelihoods
fitnb:{[mf;w;X;y]count'[g],'{x[1_y;first y]}[mf] peach prepend[w;X]@\:/:g:group y}
/ using a [log]likelihood (f)unction and (cl)assi(f)ication compute
/ densities for X
densitynb:{[f;clf;X]clf[;0],'(1_'clf) {(x . y) z}[f]'\: X}
/ given dictionary of sample densities, compute posterior probabilities
probabilitynb:{[d]d%\:sum d}
/ given prior (p)robabilities and a dictionary of sample densities,
/ predict class
predictnb:{[d] imax each flip prd flip d}
/ given prior (p)robabilities and a dictionary of sample log
/ densities, predict class
lpredictnb:{[d] imax each flip sum @[flip d;0;log]}

/ decision trees

odds:{x%sum x:count each x}
entropy:{neg sum x*2 xlog x}
eog:entropy odds group@
gain:{[n;x;y] / information gain (optionally (n)ormalized by splitinfo)
 g:eog[x]-sum (o:odds gy)*(not nk:null k:key gy)*eog each x gy:group y;
 if[n;g%:entropy o]; / gain ratio
 / TODO: distribute nulls down each branch with proportionate weight
 / if[count w:where nk;gy:(k[w]_gy),\:gy k first w];
 (g;::;gy)}

isnom:{type[x] in 1 2 4 10 11h} / is nominal

/ Improved use of continues attributes in c4.5 (quinlan) MDL
cgaina:{[gf;x;y] / continuous gain adapter
 if[isnom y;:gf[x;y]];          /TODO: handle null numbers
 g:(gain[0b;x] y >) peach -1_u:asc distinct y; / use gain (not gf)
 g@:i:imax first each g;           / highest gain (not gain ratio)
 g[0]-:xlog[2;-1+count u]%count x; / MDL adjustment
 g[0]%:entropy odds g 2;           / convert to gain ratio
 g[1]:(avg u[i+0 1])<;             / split function
 g}

/ wilson score - binary confidence interval (Edwin Bidwell Wilson)
wscore:{[f;z;n]((f+z2n%2)+-1 1*z*sqrt((z2n%4)+f-f*f)%n)%1f+z2n:z*z%n}
/ pessimistic error
perr:{[z;x]last wscore[$[1=count g:group x;0;min count each g]%n;z;n:count x]}

/ given a (t)able of classifiers and labels where the first column is
/ target attribute create a decision tree using the (g)ain (f)unction.
/ pruning subtrees with minimum (n)umber of leaves and given confidence
/ pessimistic error
dt:{[gf;n;z;t]
 if[1=count d:flip t;:first d]; / no features to test
 if[all 1_(=':) a:first d;:a];  / all values are equal
 if[not n<count a;:a];          / don't split unless >n leaves
 if[all 0>=gr:first each g:gf[a] peach 1 _d;:a]; / compute gain (ratio)
 b:@[1_g ba;1;.z.s[gf;n;z] peach ((1#ba:imax gr)_t)@]; / classify subtree
 if[z>0;if[perr[z;a]>(count each last b) wavg perr[z] peach last b;:a]]; / prune
 (ba;b)}

/ decision tree classifier: classify the (d)ictionary based on
/ decision (t)ree
dtc:{[t;d]mode dtcr[t;d]}
dtcr:{[t;d]                              / recursive component
 if[type t;:t];                          / list of values
 if[null k:d t 0;:raze t[1;1] .z.s\: d]; / dig deeper for null values
 v:.z.s[t[1;1] t[1;0] k;d];              / split on next attribute
 v}

/ given a (t)able of classifiers and labels where the first column is
/ target attribute create a decision tree using the id3 algorithm
id3:dt[gain[0b];1;0]
q45:dt[cgaina[gain[1b]]] / like c4.5 (but does not train nulls or post-prune)

/ sparse matrix manipulation

shape:{$[0h>t:type x;();n:count x;n,.z.s x 0;1#0]}
dim:count shape@
/ matrix overload of where
mwhere:{$[type x;where x;(,') over til[count x]{enlist[count[first y]#x],y:$[type y;enlist y;y]}'.z.s each x]}
/ sparse from matrix
sparse:{enlist[shape x],i,enlist (x') . i:mwhere not 0=x}
/ transpose
sflip:@[;0 2 1 3]
/ sparse matrix multiplication
smm:{enlist[(x[0;0];y[0;1])],value flip 0!select sum w*v by r,c from ej[`;flip ``c`v!1_y;flip`r``w!1_x]}
/ matrix from sparse
full:{./[x[0]#0f;flip x 1 2;:;x 3]}

/ given a (p)robability of random surfing and (A)djacency matrix
/ obtain the page rank by matrix inversion (inverse iteration)
pageranki:{[p;A]r%sum r:first mlsq[enlist r]  diag[r:n#1f]-((1f-p)%n:count A)+p*A%1f|sum peach A}

/ given a (p)robability of random surfing, (A)djacency matrix and
/ (r)ank vector, multiply by the google matrix to obtain a better
/ ranking
pagerankr:{[p;A;r]((1f-p)%n)+p*mm[A;r%1f|d]+(s:sum r where 0f=d:sum peach A)%n:count A}

/ given a (p)robability of random surfing and (A)djacency matrix
/ create the markov Google matrix
google:{[p;A]((1f-p)%n)+p*(A%1|d)+(0=d:sum peach A)%n:count A}

/ return a sorted dictionary of the ranked values
drank:{desc til[count x]!x}

/ top n svd factors
nsvd:{[n;usv]n#''@[usv;1;(n:min n,count each usv 0 2)#]}

/ use svd decomposition to predict missing exposures for new user
/ (ui=0b) or item (ui=1b) (r)ecord
foldin:{[usv;ui;r]@[usv;0 2 ui;,;mm[enlist r] mm[usv 2 0 ui] minv usv 1]}
