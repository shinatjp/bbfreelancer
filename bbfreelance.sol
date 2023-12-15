// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockGYEN is ERC20 {
    constructor() ERC20("Mock GYEN", "mGYEN") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract FreelancePlatform {
    IERC20 public gyenToken;
    FreelanceJobNFT public jobNFT;
    address public daoMember;
    uint256 public constant reviewPeriod = 3 days;
    enum JobStatus { Open, Completed, Disputed }

    struct Job {
        address employer;
        address freelancer;
        uint256 price;
        uint256 tokenId;
        bool isCompleted;
        bool isPaid;
        uint256 completionTime;
        bool autoRelease;
        bool changeRequest;
        JobStatus status; // Add a 'status' member
    }

    mapping(uint256 => Job) public jobs;
    uint256 public jobCount;

    constructor(address _gyenTokenAddress, address _nftAddress) {
        gyenToken = IERC20(_gyenTokenAddress);
        jobNFT = FreelanceJobNFT(_nftAddress);
        daoMember = msg.sender;
    }
    event JobCreated(uint256 jobId, address employer, address freelancer, uint256 price);

    function createJob(address _employer, address _freelancer, uint256 _price) public {
        jobCount++;
        Job storage job = jobs[jobCount];
        job.employer = _employer;
        job.freelancer = _freelancer;
        job.price = _price;
        job.autoRelease = true; // Set auto-release as the default payment method
        emit JobCreated(jobCount, _employer, _freelancer, _price);
    }
    

    function markJobCompleted(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(msg.sender == job.employer, "Only the employer can mark as completed");
        job.isCompleted = true;
        job.completionTime = block.timestamp;
        job.tokenId = jobNFT.mintTo(job.freelancer); // Call mintTo function directly
    }
    

    function autoReleasePayment(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(block.timestamp >= job.completionTime + reviewPeriod, "Review period is not over yet");
        require(gyenToken.balanceOf(job.employer) >= job.price, "Insufficient GYEN balance.");
        require(job.autoRelease, "Auto-release not enabled for this job");
        require(!job.isPaid, "Payment already released");
        gyenToken.transferFrom(job.employer, job.freelancer, job.price);
        job.isPaid = true;
}


    function payForJob(uint256 _jobId) public {
        Job storage job = jobs[_jobId];
        require(block.timestamp >= job.completionTime);
        require(gyenToken.balanceOf(job.employer) >= job.price, "Insufficient GYEN balance.");
        require(!job.isPaid, "Job is already paid");
        gyenToken.transferFrom(job.employer, job.freelancer, job.price);
        job.isPaid = true;
    }
    

    function daoIntervention(uint256 _jobId, bool _resolveAsComplete, bool _raiseDispute) public {
        require(msg.sender == daoMember, "Only DAO member can intervene");
        Job storage job = jobs[_jobId];
        require(job.status == JobStatus.Open, "Job is not in an open state");

        if (_raiseDispute) {
            job.status = JobStatus.Disputed;
            // Refund the employer if payment was already made
            if (job.isPaid) {
            gyenToken.transfer(job.employer, job.price);
        }
        job.isPaid = false;
        // Additional dispute resolution logic can be added here

        } else if (_resolveAsComplete) {
            job.status = JobStatus.Completed;
            job.isCompleted = true;
            payForJob(_jobId);
        //} else {
            // Other intervention logic
    }
}

}

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FreelanceJobNFT is ERC721 {
    uint256 public nextTokenId;
    IERC20 public gyenToken;
    mapping(uint256 => uint256) public clicks; // Track clicks for each NFT

    constructor(address gyenTokenAddress) ERC721("FreelanceJobNFT", "FLJNFT") {
        gyenToken = IERC20(gyenTokenAddress);
    }


    function incrementClicks(uint256 tokenId) public {
        clicks[tokenId]++;
    }

    function calculateRevenue(uint256 tokenId) public view returns (uint256) {
        uint256 revenuePerClick = 0.5 * (10 ** 18); // 0.5 GYEN per click
        return clicks[tokenId] * revenuePerClick;
    }

    function distributeRevenue(uint256 tokenId) public {
        uint256 revenue = calculateRevenue(tokenId);
        address recipient = ownerOf(tokenId); // Assuming the NFT owner receives the revenue
        require(gyenToken.balanceOf(address(this)) >= revenue, "Insufficient GYEN in contract");
        gyenToken.transfer(recipient, revenue);
}

    function mintTo(address recipient) public returns (uint256) {
        uint256 newItemId = nextTokenId++;
        _mint(recipient, newItemId);
        return newItemId;
    }
    
}