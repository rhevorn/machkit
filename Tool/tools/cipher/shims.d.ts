declare module "sm-crypto" {
  const smCrypto: {
    sm2: {
      generateKeyPairHex: () => { publicKey: string; privateKey: string };
      getPublicKeyFromPrivateKey: (privateKey: string) => string;
      doEncrypt: (msg: string, publicKey: string, cipherMode?: number) => string;
      doDecrypt: (encryptData: string, privateKey: string, cipherMode?: number) => string;
    };
    sm3: (str: string) => string;
    sm4: {
      encrypt: (msg: string, key: string, options?: Record<string, unknown>) => string;
      decrypt: (encryptData: string, key: string, options?: Record<string, unknown>) => string;
    };
  };
  export default smCrypto;
}
