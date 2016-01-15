radius = 128;

qFactor = radius-1;

len     = ceil(radius) * 6;
b0Coeff = 1.57825 + (2.44413 * qFactor) + (1.4281 * qFactor * qFactor) + (0.422205 * qFactor * qFactor * qFactor);
b1Coeff = (2.44413 * qFactor) + (2.85619 * qFactor * qFactor) + (1.26661 * qFactor * qFactor * qFactor);
b2Coeff = (-1.4281 * qFactor * qFactor) + (-1.26661 * qFactor * qFactor * qFactor);
b3Coeff = 0.422205 * qFactor * qFactor * qFactor;
normalizationCoeff = 1 - ((b1Coeff + b2Coeff + b3Coeff) / b0Coeff);
vDenCoeff = [b0Coeff, -b1Coeff, -b2Coeff, -b3Coeff] / b0Coeff;
vXSignal = zeros(len-1, 1);
vXSignal(len/2) = 1;
vYSignal = filter(normalizationCoeff, vDenCoeff, vXSignal);
vYSignal = filter(normalizationCoeff, vDenCoeff, vYSignal(end:-1:1));

figure(1);
clf(1);

x = -len/2+1:len/2-1;

plot(x,vYSignal,'LineWidth',2);


x = -len/2:len/2-1;
g = normpdf(x,0,radius);
hold on; plot(x,g);
axis([-len/2-10,len/2+10, 0, max(g)+max(g)/10])

