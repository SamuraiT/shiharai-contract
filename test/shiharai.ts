import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract } from 'ethers'
import { ethers } from 'hardhat'

describe('Shiharai', function () {
  let shirahaiContract: Contract,
    owner: SignerWithAddress,
    alice: SignerWithAddress,
    bob: SignerWithAddress,
    erc20: Contract

  beforeEach(async () => {
    ;[owner, alice, bob] = await ethers.getSigners()
    const MockERC20 = await ethers.getContractFactory('MockERC20')
    erc20 = await MockERC20.deploy()
    await erc20.deployed()

    const ShirahaiContract = await ethers.getContractFactory('Shiharai')
    shirahaiContract = await ShirahaiContract.deploy(erc20.address)
    await shirahaiContract.deployed()
  })

  describe('setERC20', () => {
    it('setErc20 successfully', async () => {
      await shirahaiContract.setERC20(ethers.constants.AddressZero)
      expect(await shirahaiContract.erc20()).to.be.eq(
        ethers.constants.AddressZero
      )
    })

    it('reverts with none owner', async () => {
      await expect(
        shirahaiContract.connect(alice).setERC20(ethers.constants.AddressZero)
      ).to.be.reverted
      expect(await shirahaiContract.erc20()).to.be.eq(erc20.address)
    })
  })
})
