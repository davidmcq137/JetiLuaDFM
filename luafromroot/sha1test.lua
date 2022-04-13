function sha1(message)

  -- magic numbers
  local h0 = 0x67452301;
  local h1 = 0xEFCDAB89;
  local h2 = 0x98BADCFE;
  local h3 = 0x10325476;
  local h4 = 0xC3D2E1F0;
  
  -- padding, etc
  local bits = #message * 8;
  message = message  .. '\x80';
  local paddingAmount = (120 - (#message % 64)) % 64;
  message = message .. string.rep('\0', paddingAmount);
  message = message .. string.pack('>I8', bits);
  
  -- rotate function
  local function rol(value, bits)
    return (((value) << (bits)) | ((value) >> (32 - (bits))));
  end;
  
  -- process each chunk
  for i=1,#message,64 do
    local chunk = string.sub(message, i, i+63);
    local parts = {};
    
    -- split chunk into 16 parts
    for i=0,15 do
      parts[i] = string.unpack('>I4',string.sub(chunk, 1+i*4, 4+i*4));
      --print(parts[i]);
    end;
    
    -- extend into 80 parts
    for i=16,79 do
      parts[i] = rol(parts[i-3] ~ parts[i-8] ~ parts[i-14] ~ parts[i-16], 1) & 0xFFFFFFFF;
    end;
    
    -- initialise hash values
    local a,b,c,d,e = h0,h1,h2,h3,h4;
    local f,k;
    
    -- main loop
    for i=0,79 do
      if 0 <= i and i <= 19 then
        f = (b & c) | ((~b) & d)
        k = 0x5A827999
      elseif 20 <= i and i <= 39 then
        f = b ~ c ~ d
        k = 0x6ED9EBA1
      elseif 40 <= i and i <= 59 then
        f = (b & c) | (b & d) | (c & d) 
        k = 0x8F1BBCDC
      elseif 60 <= i and i <= 79 then
        f = b ~ c ~ d
        k = 0xCA62C1D6
      end

      local temp = (rol(a, 5) + f + e + k + parts[i]) & 0xFFFFFFFF
      e = d;
      d = c;
      c = rol(b, 30);
      b = a;
      a = temp;
    end;
    
    h0 = (h0 + a) & 0xFFFFFFFF;
    h1 = (h1 + b) & 0xFFFFFFFF;
    h2 = (h2 + c) & 0xFFFFFFFF;
    h3 = (h3 + d) & 0xFFFFFFFF;
    h4 = (h4 + e) & 0xFFFFFFFF;
    
  end;
  
  return string.format('%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4);
  
end

print("sha1:", sha1("apple"))
