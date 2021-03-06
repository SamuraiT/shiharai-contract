/* eslint-disable camelcase */
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { expect } from 'chai'
import { Contract, utils, BigNumber } from 'ethers'
import { ethers } from 'hardhat'
import {
  IERC20__factory,
  MockERC20__factory,
  Shiharai__factory
  // eslint-disable-next-line node/no-missing-import
} from '../typechain'

const increaseTime = async (seconds: number) => {
  await ethers.provider.send('evm_increaseTime', [seconds])
  await ethers.provider.send('evm_mine', [])
}

const setTimeAs = async (unixTime: number) => {
  await ethers.provider.send('evm_setNextBlockTimestamp', [unixTime])
  await ethers.provider.send('evm_mine', [])
}

describe('Shiharai', function () {
  let shirahaiContract: Contract,
    owner: SignerWithAddress,
    alice: SignerWithAddress,
    bob: SignerWithAddress,
    erc20: Contract

  beforeEach(async () => {
    ;[owner, alice, bob] = await ethers.getSigners()
    const MockERC20 = new MockERC20__factory(owner)
    erc20 = await MockERC20.deploy('usdc')
    await erc20.deployed()
    const amount = utils.parseUnits('1000', 18)
    erc20.mint(alice.address, amount)
    erc20.mint(bob.address, amount)
    // const ShirahaiContract = await ethers.getContractFactory('Shiharai')
    const ShiharaiContract = new Shiharai__factory(owner)
    shirahaiContract = await ShiharaiContract.deploy(erc20.address)
    await shirahaiContract.deployed()
  })

  describe('issueAgreement', () => {
    let issueAgreement: any, nextMonth: number

    this.beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('100', 18),
        term: 1, // 1month
        paysAt: nextMonth
      }
    })

    it('issue agreement successfully', async () => {
      const amount = utils.parseUnits('10000', 18)
      await erc20.approve(shirahaiContract.address, amount)
      await shirahaiContract.deposit(erc20.address, amount)

      await expect(
        shirahaiContract.issueAgreement(...Object.values(issueAgreement))
      ).to.emit(shirahaiContract, 'IssuedAgreement')

      const agreement = await shirahaiContract.agreements(1)
      expect(agreement.issuer).to.be.eq(owner.address)
      expect(agreement.undertaker).to.be.eq(alice.address)
      expect(agreement.payment).to.be.eq(erc20.address)
      expect(agreement.amount).to.be.eq(utils.parseUnits('100', 18))
      expect(agreement.paysAt).to.be.eq(nextMonth)
    })
  })

  describe('confirmAgreement', () => {
    let issueAgreement: any, nextMonth: number

    beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('10000', 18),
        term: 1, // 1month
        paysAt: nextMonth
      }

      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await shirahaiContract.deposit(erc20.address, issueAgreement.amount)
      await shirahaiContract.issueAgreement(...Object.values(issueAgreement))
    })

    it('successfully continue agreeemnt', async () => {
      await expect(shirahaiContract.connect(alice).confirmAgreement(1)).to.emit(
        shirahaiContract,
        'ConfirmAgreement'
      )
    })

    it('revert to if user try confirm twice', async () => {
      await expect(shirahaiContract.connect(alice).confirmAgreement(1)).to.emit(
        shirahaiContract,
        'ConfirmAgreement'
      )

      await expect(
        shirahaiContract.connect(alice).confirmAgreement(1)
      ).to.be.revertedWith('INVALID: ALREADY CONFIRMED')
    })
  })
  describe('deposit', () => {
    it('deposit successfully', async () => {
      const balance = await erc20.balanceOf(owner.address)
      const amount = utils.parseUnits('10000', 18)
      await erc20.approve(shirahaiContract.address, amount)
      await expect(shirahaiContract.deposit(erc20.address, amount))
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(owner.address, erc20.address, amount)
      expect(await erc20.balanceOf(owner.address)).to.eq(balance.sub(amount))
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)

      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      expect(await Ctoken.balanceOf(shirahaiContract.address)).to.eq(amount)
    })

    it('deposit successfully with alice', async () => {
      const balance = await erc20.balanceOf(alice.address)
      const amount = utils.parseUnits('1000', 18)
      await erc20.connect(alice).approve(shirahaiContract.address, amount)
      await expect(
        shirahaiContract.connect(alice).deposit(erc20.address, amount)
      )
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(alice.address, erc20.address, amount)
      expect(await erc20.balanceOf(alice.address)).to.eq(balance.sub(amount))
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(alice.address, erc20.address)
      ).to.eq(amount)

      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      expect(await Ctoken.balanceOf(shirahaiContract.address)).to.eq(amount)
    })

    it('revert deposit', async () => {
      const balance = await erc20.balanceOf(alice.address)
      const amount = utils.parseUnits('1000000', 18)
      await erc20.connect(alice).approve(shirahaiContract.address, amount)
      await expect(
        shirahaiContract.connect(alice).deposit(erc20.address, amount)
      ).to.be.reverted
      expect(await erc20.balanceOf(alice.address)).to.eq(balance)
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(0)
      expect(
        await shirahaiContract.depositedAmountMap(alice.address, erc20.address)
      ).to.eq(0)
    })
  })

  describe('depositAndissueAgreement', () => {
    it('successfully issue and desposit', async () => {
      const now = new Date()
      const nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      const amount = utils.parseUnits('100', 18)
      const issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: amount,
        term: 1, // 1month
        paysAt: nextMonth
      }

      const balance = await erc20.balanceOf(owner.address)
      await erc20.approve(shirahaiContract.address, amount)
      await expect(
        shirahaiContract.depositAndissueAgreement(
          ...Object.values(issueAgreement)
        )
      )
        .to.emit(shirahaiContract, 'IssuedAgreement')
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(owner.address, erc20.address, amount)

      expect(await erc20.balanceOf(owner.address)).to.eq(balance.sub(amount))
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(amount)
      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)
      const agreement = await shirahaiContract.agreements(1)
      expect(agreement.issuer).to.be.eq(owner.address)
      expect(agreement.undertaker).to.be.eq(alice.address)
      expect(agreement.payment).to.be.eq(erc20.address)
      expect(agreement.amount).to.be.eq(amount)

      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      expect(await Ctoken.balanceOf(shirahaiContract.address)).to.eq(amount)
    })
  })

  describe('getAgreements', () => {
    let now: Date, nextMonth: number, amount: BigNumber, balance: BigNumber

    beforeEach(async () => {
      now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      amount = utils.parseUnits('1000', 18)
      const issueAgreementWithAlice = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: amount,
        term: 1, // 1month
        paysAt: nextMonth
      }
      const issueAgreementWithBob = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: bob.address,
        token: erc20.address,
        amount: amount,
        term: 1, // 1month
        paysAt: nextMonth
      }
      balance = await erc20.balanceOf(owner.address)
      await erc20.approve(shirahaiContract.address, balance)
      await shirahaiContract.depositAndissueAgreement(
        ...Object.values(issueAgreementWithAlice)
      )

      await shirahaiContract.depositAndissueAgreement(
        ...Object.values(issueAgreementWithBob)
      )
    })

    it('getIssuersAgreements', async () => {
      const agreements = await shirahaiContract.getIssuersAgreements(
        owner.address
      )

      expect(agreements[0].issuer).to.be.eq(owner.address)
      expect(agreements[0].undertaker).to.be.eq(alice.address)
      expect(agreements[0].payment).to.be.eq(erc20.address)
      expect(agreements[0].amount).to.be.eq(amount)

      expect(agreements[1].issuer).to.be.eq(owner.address)
      expect(agreements[1].undertaker).to.be.eq(bob.address)
      expect(agreements[1].payment).to.be.eq(erc20.address)
      expect(agreements[1].amount).to.be.eq(amount)
    })
  })

  describe('claim', () => {
    let issueAgreement: any, nextMonth: number

    this.beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('10000', 18),
        term: 1, // 1month
        paysAt: nextMonth
      }
    })

    it('claim successfully', async () => {
      const amount = utils.parseUnits('10000', 18)
      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await shirahaiContract.deposit(erc20.address, amount)

      await expect(
        shirahaiContract.issueAgreement(...Object.values(issueAgreement))
      ).to.emit(shirahaiContract, 'IssuedAgreement')

      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)
      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      const days = 60 * 60 * 24

      await shirahaiContract.connect(alice).confirmAgreement(1)
      expect(await Ctoken.balanceOf(alice.address)).to.be.eq(amount)

      await Ctoken.connect(alice).approve(
        shirahaiContract.address,
        ethers.constants.MaxUint256
      )

      await increaseTime(days * 45)
      await expect(shirahaiContract.connect(alice).claim(1)).to.emit(
        shirahaiContract,
        'Claimed'
      )

      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(0)
    })

    it('revert if undertaker try to claim twice', async () => {
      const amount = utils.parseUnits('10000', 18)
      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await shirahaiContract.deposit(erc20.address, amount)

      await expect(
        shirahaiContract.issueAgreement(...Object.values(issueAgreement))
      ).to.emit(shirahaiContract, 'IssuedAgreement')

      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(amount)
      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      const days = 60 * 60 * 24

      await shirahaiContract.connect(alice).confirmAgreement(1)
      expect(await Ctoken.balanceOf(alice.address)).to.be.eq(amount)

      await Ctoken.connect(alice).approve(
        shirahaiContract.address,
        ethers.constants.MaxUint256
      )

      await increaseTime(days * 31)
      await expect(shirahaiContract.connect(alice).claim(1)).to.emit(
        shirahaiContract,
        'Claimed'
      )

      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(0)

      await expect(shirahaiContract.connect(alice).claim(1)).to.be.revertedWith(
        'INVALID: PAID ALL AMOUNT'
      )
    })
  })

  describe('continueAgreement', () => {
    let issueAgreement: any, nextMonth: number

    beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('10000', 18),
        term: 1, // 1month
        paysAt: nextMonth
      }

      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await shirahaiContract.deposit(erc20.address, issueAgreement.amount)
      await shirahaiContract.issueAgreement(...Object.values(issueAgreement))

      await shirahaiContract.connect(alice).confirmAgreement(1)
    })

    it('successfully continue agreeemnt', async () => {
      const current = Date.now() / 1000
      await shirahaiContract.deposit(erc20.address, issueAgreement.amount)
      await expect(shirahaiContract.continueAgreement(1)).to.emit(
        shirahaiContract,
        'ContinueAgreement'
      )
      const firstAgreement = await shirahaiContract.agreements(1)
      expect(firstAgreement.paysAt).to.be.eq(firstAgreement.paysAt)
      expect(firstAgreement.endedAt.toNumber()).to.be.gte(current)
      expect(firstAgreement.nextAgreementId).to.be.eq(2)

      const nextAgreement = await shirahaiContract.agreements(2)
      expect(nextAgreement.paysAt.toNumber()).to.be.gte(current)
      expect(nextAgreement.endedAt.toNumber()).to.be.eq(0)
      expect(nextAgreement.nextAgreementId).to.be.eq(0)
      expect(nextAgreement.issuer).to.be.eq(firstAgreement.issuer)
      expect(nextAgreement.undertaker).to.be.eq(firstAgreement.undertaker)
      expect(nextAgreement.amount).to.be.eq(firstAgreement.amount)
      expect(nextAgreement.payment).to.be.eq(firstAgreement.payment)
    })

    it('revert if depoisit is not enough', async () => {
      await expect(shirahaiContract.continueAgreement(1)).to.be.revertedWith(
        'INSUFFICIENT DEPOSIT'
      )
    })
    it('success with continueagreements', async () => {
      const nextIssueAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: bob.address,
        token: erc20.address,
        amount: utils.parseUnits('10000', 18),
        term: 1, // 1month
        paysAt: nextMonth
      }

      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await shirahaiContract.deposit(erc20.address, nextIssueAgreement.amount)
      await shirahaiContract.issueAgreement(
        ...Object.values(nextIssueAgreement)
      )

      await shirahaiContract.connect(bob).confirmAgreement(2)

      await shirahaiContract.deposit(
        erc20.address,
        issueAgreement.amount.mul(2)
      )
      await expect(shirahaiContract.continueAgreements([1, 2])).to.emit(
        shirahaiContract,
        'ContinueAgreement'
      )
    })
  })

  describe('depositAndissueVestingAgreement', () => {
    let issueVestingAgreement: any, nextMonth: number

    beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueVestingAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('10000', 18),
        term: 1, // 1month
        paysAt: nextMonth,
        cliffEndedAt: nextMonth,
        vestingDuration: 365, // 30 days
        revokeDays: 30
      }
    })

    it('successfully deposit and issue agreement', async () => {
      const balance = await erc20.balanceOf(owner.address)
      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await expect(
        shirahaiContract.depositAndissueVestingAgreement(
          ...Object.values(issueVestingAgreement)
        )
      )
        .to.emit(shirahaiContract, 'IssuedAgreement')
        .to.emit(shirahaiContract, 'Deposit')
        .withArgs(owner.address, erc20.address, issueVestingAgreement.amount)

      expect(await erc20.balanceOf(owner.address)).to.eq(
        balance.sub(issueVestingAgreement.amount)
      )
      expect(await erc20.balanceOf(shirahaiContract.address)).to.eq(
        issueVestingAgreement.amount
      )
      expect(
        await shirahaiContract.depositedAmountMap(owner.address, erc20.address)
      ).to.eq(issueVestingAgreement.amount)
      const agreement = await shirahaiContract.agreements(1)
      expect(agreement.issuer).to.be.eq(owner.address)
      expect(agreement.undertaker).to.be.eq(alice.address)
      expect(agreement.payment).to.be.eq(erc20.address)
      expect(agreement.amount).to.be.eq(issueVestingAgreement.amount)

      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      expect(await Ctoken.balanceOf(shirahaiContract.address)).to.eq(
        issueVestingAgreement.amount
      )
    })
  })

  describe('claimForVesting', () => {
    let issueVestingAgreement: any, nextMonth: number
    beforeEach(async () => {
      const now = new Date()
      nextMonth =
        new Date(
          now.getFullYear(),
          now.getMonth() + 1,
          now.getDay()
        ).getTime() / 1000

      issueVestingAgreement = {
        name: utils.keccak256(utils.toUtf8Bytes('hoge')),
        with: alice.address,
        token: erc20.address,
        amount: utils.parseUnits('10000', 18),
        term: 1, // 1month
        paysAt: nextMonth,
        cliffEndedAt: nextMonth,
        vestingDuration: 365, // 30 days
        revokeDays: 0
      }

      await erc20.approve(shirahaiContract.address, ethers.constants.MaxUint256)
      await shirahaiContract.depositAndissueVestingAgreement(
        ...Object.values(issueVestingAgreement)
      )
      await shirahaiContract.connect(alice).confirmAgreement(1)
    })

    it('successfully claim', async () => {
      const days = 60 * 60 * 24
      await setTimeAs(nextMonth + days * 60)
      const amount = await shirahaiContract.amountToBePiad(1)
      const delta = issueVestingAgreement.amount.div(
        issueVestingAgreement.vestingDuration
      )
      const fromEstimatedAmount = delta.mul(
        Math.ceil(
          (nextMonth + days * 60 - issueVestingAgreement.cliffEndedAt) / days
        )
      )
      expect(amount).to.be.closeTo(fromEstimatedAmount, utils.parseEther('1'))
      const ctoken = await shirahaiContract.supportedTokensMap(erc20.address)
      const Ctoken = IERC20__factory.connect(ctoken, owner)
      await Ctoken.connect(alice).approve(
        shirahaiContract.address,
        ethers.constants.MaxUint256
      )

      const amount2 = await shirahaiContract.amountToBePiad(1)
      await expect(shirahaiContract.connect(alice).claim(1)).to.emit(
        shirahaiContract,
        'Claimed'
      )
      expect(await erc20.balanceOf(alice.address)).to.be.closeTo(
        amount2,
        utils.parseEther('1000')
      )
    })
  })
})
